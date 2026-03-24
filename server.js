const express = require('express');
const { createClient } = require('@supabase/supabase-js');

const app = express();

require('dotenv').config();

console.log('🚀 THIS IS THE NEW SERVER FILE');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase =
  supabaseUrl && supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      })
    : null;

if (!supabase) {
  console.warn(
    '⚠️  SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing — contact_unlocks will not be written from /success',
  );
}

/**
 * Base URL Stripe redirects the *browser* to after pay (must be reachable from the phone,
 * not http://127.0.0.1:4000 or http://localhost:4000). Port 4040 is ngrok's inspector UI,
 * not your Express app — use the HTTPS tunnel URL that forwards to port 4000.
 */
const publicBaseUrl = (
  process.env.PUBLIC_BASE_URL ||
  process.env.API_URL ||
  'https://telegraphic-banausic-kathey.ngrok-free.dev'
)
  .trim()
  .replace(/\/$/, '');

if (/127\.0\.0\.1|localhost|:4040(\/|$|\?)/i.test(publicBaseUrl)) {
  console.warn(
    '⚠️  PUBLIC_BASE_URL / API_URL looks like localhost, 127.0.0.1, or port 4040 — Stripe return URLs often fail on physical devices. Use your HTTPS ngrok URL (tunnel to :4000, not the :4040 inspector).',
  );
}

app.use(express.json());

/**
 * Sets bids.payment_status from Stripe Checkout metadata. Runs whenever the session
 * is paid — does not depend on contact_unlocks metadata being complete (Flutter polls bids).
 */
async function updateBidsPaymentStatusFromSession(session) {
  if (!supabase || !session || session.payment_status !== 'paid') return;

  const md = session.metadata || {};
  const requestId = md.request_id != null ? String(md.request_id).trim() : '';
  if (!requestId) {
    console.warn('bids: paid session missing metadata.request_id');
    return;
  }

  const bidId = md.bid_id != null ? String(md.bid_id).trim() : '';
  const receiverId = md.receiver_id != null ? String(md.receiver_id).trim() : '';

  if (bidId) {
    const { error } = await supabase
      .from('bids')
      .update({ payment_status: 'paid' })
      .eq('id', bidId);
    if (error) console.error('bids payment_status (by bid_id):', error);
    return;
  }
  if (receiverId) {
    const { error } = await supabase
      .from('bids')
      .update({ payment_status: 'paid' })
      .eq('request_id', requestId)
      .eq('bidder_id', receiverId);
    if (error) console.error('bids payment_status (request + bidder):', error);
    return;
  }

  const { error: fallbackErr } = await supabase
    .from('bids')
    .update({ payment_status: 'paid' })
    .eq('request_id', requestId);
  if (fallbackErr) console.error('bids payment_status (request_id only):', fallbackErr);
}

/**
 * After Stripe redirects here with session_id, we retrieve the session and
 * upsert contact_unlocks (authoritative server-side unlock).
 */
async function recordContactUnlockIfPaid(session) {
  if (!supabase || !session || session.payment_status !== 'paid') return;

  await updateBidsPaymentStatusFromSession(session);

  const md = session.metadata || {};
  const userId = md.user_id && String(md.user_id).trim();
  const artistId = md.receiver_id && String(md.receiver_id).trim();
  const requestId = md.request_id && String(md.request_id).trim();

  if (!userId || !artistId || !requestId) {
    console.warn('contact_unlocks: missing metadata', { userId, artistId, requestId });
    return;
  }

  const depositRaw = md.deposit_amount != null ? String(md.deposit_amount).trim() : '';
  const depositNum =
    depositRaw !== '' && !Number.isNaN(Number.parseFloat(depositRaw))
      ? Number.parseFloat(depositRaw)
      : null;

  const { error } = await supabase.from('contact_unlocks').upsert(
    {
      user_id: userId,
      artist_id: artistId,
      request_id: requestId,
      status: 'paid',
      deposit_amount: depositNum,
    },
    { onConflict: 'user_id,request_id,artist_id' },
  );

  if (error) {
    console.error('contact_unlocks upsert failed:', error);
  } else {
    console.log('✅ contact_unlocks recorded', { requestId, artistId });
  }
}

/**
 * App calls this after returning from Stripe (in addition to GET /success in the browser).
 * Retrieves the Checkout session and upserts contact_unlocks when payment_status === 'paid'.
 */
app.post('/verify-payment', async (req, res) => {
  try {
    const sessionId = req.body?.session_id;
    if (!sessionId || String(sessionId).trim() === '') {
      return res.status(400).json({ error: 'session_id required' });
    }
    const session = await stripe.checkout.sessions.retrieve(String(sessionId));
    await recordContactUnlockIfPaid(session);
    const paid = session.payment_status === 'paid';
    return res.json({
      ok: true,
      payment_status: session.payment_status,
      paid,
    });
  } catch (err) {
    console.error('verify-payment:', err);
    return res.status(500).json({ error: err.message });
  }
});

/**
 * App calls after verified Stripe payment to mirror unlock state in Supabase
 * (contact_unlocks + bids.payment_status). Uses service role — keep server URL private.
 */
app.post('/success', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    const { user_id, request_id, artist_id } = req.body || {};
    const userId = user_id != null ? String(user_id).trim() : '';
    const requestId = request_id != null ? String(request_id).trim() : '';
    const artistId = artist_id != null ? String(artist_id).trim() : '';
    if (!userId || !requestId || !artistId) {
      return res
        .status(400)
        .json({ error: 'user_id, request_id, and artist_id required' });
    }

    const { error: unlockErr } = await supabase.from('contact_unlocks').upsert(
      {
        user_id: userId,
        artist_id: artistId,
        request_id: requestId,
        status: 'paid',
      },
      { onConflict: 'user_id,request_id,artist_id' },
    );
    if (unlockErr) {
      console.error('POST /success contact_unlocks:', unlockErr);
      return res.status(500).json({ error: unlockErr.message });
    }

    const { error: bidErr } = await supabase
      .from('bids')
      .update({ payment_status: 'paid' })
      .eq('request_id', requestId)
      .eq('bidder_id', artistId);

    if (bidErr) {
      console.error('POST /success bids:', bidErr);
      return res.status(500).json({ error: bidErr.message });
    }

    return res.json({ success: true });
  } catch (err) {
    console.error('POST /success:', err);
    return res.status(500).json({ error: err.message });
  }
});

app.post('/create-payment', async (req, res) => {
  try {
    const { amount, bid_id, receiver_id, request_id, user_id, deposit_amount } =
      req.body;
    const receiverId =
      receiver_id != null && String(receiver_id).trim().length > 0
        ? String(receiver_id).trim()
        : '';
    const requestId =
      request_id != null && String(request_id).trim().length > 0
        ? String(request_id).trim()
        : '';
    const userId =
      user_id != null && String(user_id).trim().length > 0
        ? String(user_id).trim()
        : '';
    const depositMeta =
      deposit_amount != null && String(deposit_amount).trim().length > 0
        ? String(deposit_amount).trim()
        : String(amount);

    const successUrl =
      `${publicBaseUrl}/success?session_id={CHECKOUT_SESSION_ID}&kind=deposit` +
      (receiverId ? `&receiver_id=${encodeURIComponent(receiverId)}` : '');

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'aud',
            product_data: {
              name: 'Tattoo Bid Payment',
            },
            unit_amount: Math.round(Number(amount) * 100),
          },
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: `${publicBaseUrl}/cancel`,
      client_reference_id: userId || undefined,
      metadata: {
        bid_id: bid_id != null ? String(bid_id) : '',
        receiver_id: receiverId,
        request_id: requestId,
        user_id: userId,
        deposit_amount: depositMeta,
      },
    });

    console.log(session.url);

    return res.json({ url: session.url });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

app.get('/success', async (req, res) => {
  const { session_id } = req.query;
  const sessionId = session_id;
  const kind = req.query.kind || 'deposit';
  const receiverId = req.query.receiver_id || '';

  if (sessionId) {
    try {
      const session = await stripe.checkout.sessions.retrieve(String(sessionId));

      if (session.payment_status === 'paid' && supabase) {
        // Same path as POST /verify-payment: bids first, then contact_unlocks when metadata complete.
        if (kind === 'deposit') {
          await recordContactUnlockIfPaid(session);
        } else {
          await updateBidsPaymentStatusFromSession(session);
        }
      }
    } catch (e) {
      console.error('GET /success Stripe / unlock:', e);
    }
  }

  const deepLink = `tattsbid://checkout/success?session_id=${encodeURIComponent(
    sessionId || '',
  )}&kind=${encodeURIComponent(kind)}${
    receiverId ? `&receiver_id=${encodeURIComponent(receiverId)}` : ''
  }`;

  res.send(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Payment successful</title>
  </head>
  <body style="font-family: Arial, sans-serif; text-align: center; padding: 40px;">
    <h2>Payment successful</h2>
    <p>Opening the app in 1 second...</p>
    <p><a href="${deepLink}">Tap here if it does not open automatically</a></p>
    <script>
      setTimeout(function () {
        window.location.href = ${JSON.stringify(deepLink)};
      }, 1000);
    </script>
  </body>
</html>`);
});

app.get('/cancel', (req, res) => {
  res.send('Payment cancelled.');
});

app.listen(4000, '0.0.0.0', () => {
  console.log('Server running on port 4000');
});

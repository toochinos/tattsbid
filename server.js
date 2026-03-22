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

app.use(express.json());

/**
 * After Stripe redirects here with session_id, we retrieve the session and
 * upsert contact_unlocks (authoritative server-side unlock).
 */
async function recordContactUnlockIfPaid(session) {
  if (!supabase || !session || session.payment_status !== 'paid') return;

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

app.post('/api/pay', async (req, res) => {
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
      'http://127.0.0.1:4000/success?session_id={CHECKOUT_SESSION_ID}&kind=deposit' +
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
      cancel_url: 'http://127.0.0.1:4000/cancel',
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
  const sessionId = req.query.session_id;
  const kind = req.query.kind || 'deposit';
  const receiverId = req.query.receiver_id || '';

  if (kind === 'deposit' && supabase && sessionId) {
    try {
      const session = await stripe.checkout.sessions.retrieve(String(sessionId));
      await recordContactUnlockIfPaid(session);
    } catch (e) {
      console.error('Stripe session retrieve / contact_unlocks:', e);
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

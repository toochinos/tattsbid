const express = require('express');
const app = express();

require('dotenv').config();

console.log("🚀 THIS IS THE NEW SERVER FILE");
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

app.use(express.json());

app.post('/api/pay', async (req, res) => {
  try {
    const { amount, bid_id, receiver_id } = req.body;
    const receiverId =
      receiver_id != null && String(receiver_id).trim().length > 0
        ? String(receiver_id).trim()
        : '';
    const successUrl =
      'http://127.0.0.1:4000/success?session_id={CHECKOUT_SESSION_ID}&kind=deposit' +
      (receiverId
        ? `&receiver_id=${encodeURIComponent(receiverId)}`
        : '');

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
            unit_amount: amount * 100,
          },
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: 'http://127.0.0.1:4000/cancel',
      metadata: {
        bid_id: bid_id != null ? String(bid_id) : '',
        receiver_id: receiverId,
      },
    });

    console.log(session.url);

    // ✅ THIS is what sends JSON
    return res.json({ url: session.url });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

app.get('/success', (req, res) => {
  const sessionId = req.query.session_id;
  const kind = req.query.kind || 'deposit';
  const receiverId = req.query.receiver_id || '';
  const deepLink = `tattsbid://checkout/success?session_id=${encodeURIComponent(
    sessionId || '',
  )}&kind=${encodeURIComponent(kind)}${
    receiverId
      ? `&receiver_id=${encodeURIComponent(receiverId)}`
      : ''
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

app.listen(4000, '0.0.0.0');


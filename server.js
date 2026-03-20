const express = require('express');
const app = express();

require('dotenv').config();

console.log("🚀 THIS IS THE NEW SERVER FILE");
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

app.use(express.json());

app.post('/api/pay', async (req, res) => {
  try {
    const { amount, bid_id } = req.body;

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
      success_url: 'http://localhost:3000/success',
      cancel_url: 'http://localhost:3000/cancel',
      metadata: {
        bid_id: bid_id != null ? String(bid_id) : '',
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

app.listen(4000, '0.0.0.0');


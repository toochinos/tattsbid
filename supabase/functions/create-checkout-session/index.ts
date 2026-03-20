// Create Stripe Checkout Session for subscription.
// Requires: STRIPE_SECRET_KEY, STRIPE_PRICE_ID
// Set secrets: supabase secrets set STRIPE_SECRET_KEY=sk_xxx STRIPE_PRICE_ID=price_xxx

import Stripe from 'https://esm.sh/stripe@14?target=denonext';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-11-20',
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } =
      await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const body = await req.json().catch(() => ({}));
    const priceIdFromBody = body?.price_id as string | undefined;
    const priceId = priceIdFromBody ?? Deno.env.get('STRIPE_PRICE_ID');
    if (!priceId) {
      return new Response(
        JSON.stringify({ error: 'No price_id provided and STRIPE_PRICE_ID not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    let successUrl: string;
    let cancelUrl: string;
    const successBaseUrl = body?.success_base_url as string | undefined;
    const cancelBaseUrl = body?.cancel_base_url as string | undefined;
    if (successBaseUrl) {
      successUrl = `${successBaseUrl}${successBaseUrl.includes('?') ? '&' : '?'}session_id={CHECKOUT_SESSION_ID}`;
      cancelUrl = cancelBaseUrl ?? successBaseUrl.replace(/checkout\/success.*$/, 'paywall');
    } else {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const functionsUrl = `${supabaseUrl}/functions/v1`;
      successUrl = `${functionsUrl}/checkout-redirect?session_id={CHECKOUT_SESSION_ID}`;
      cancelUrl = `${functionsUrl}/checkout-redirect?cancel=1`;
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: user.id,
      customer_email: user.email ?? undefined,
    });

    return new Response(
      JSON.stringify({ url: session.url }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

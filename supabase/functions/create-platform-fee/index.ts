// Create Stripe Checkout Session for paying deposit fee (10% of winning bid).
// Requires: STRIPE_SECRET_KEY
// Optional env:
// - PLATFORM_FEE_CURRENCY (default: aud)
// - PLATFORM_FEE_PERCENT (default: 10)
//
// Call with body:
// {
//   request_id: string,
//   bid_id: string,
//   success_base_url?: string, // e.g. 'saasapp://checkout/success' or https URL
//   cancel_base_url?: string,
//   currency?: string,
// }

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

function normalizeCurrency(value: unknown, fallback: string): string {
  const s = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return s.length === 3 ? s : fallback;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json().catch(() => ({}));
    const requestId = body?.request_id as string | undefined;
    const bidId = body?.bid_id as string | undefined;
    if (!requestId || !bidId) {
      return new Response(
        JSON.stringify({ error: 'Missing request_id or bid_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const currency = normalizeCurrency(
      body?.currency,
      (Deno.env.get('PLATFORM_FEE_CURRENCY') ?? 'aud').toLowerCase(),
    );

    // Validate ownership and fetch bid amount from DB (prevents client tampering).
    const { data: requestRow, error: requestErr } = await supabase
      .from('tattoo_requests')
      .select('id, user_id, winning_bid_id')
      .eq('id', requestId)
      .maybeSingle();
    if (requestErr || !requestRow) {
      return new Response(JSON.stringify({ error: 'Request not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (requestRow.user_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not request owner' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (requestRow.winning_bid_id && requestRow.winning_bid_id !== bidId) {
      return new Response(JSON.stringify({ error: 'Bid is not the winning bid' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: bidRow, error: bidErr } = await supabase
      .from('bids')
      .select('id, request_id, amount')
      .eq('id', bidId)
      .maybeSingle();
    if (bidErr || !bidRow) {
      return new Response(JSON.stringify({ error: 'Bid not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (bidRow.request_id !== requestId) {
      return new Response(JSON.stringify({ error: 'Bid does not belong to request' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const amount = typeof bidRow.amount === 'number' ? bidRow.amount : Number(bidRow.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid bid amount' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const percent = (() => {
      const raw = Deno.env.get('PLATFORM_FEE_PERCENT') ?? '10';
      const n = Number(raw);
      return Number.isFinite(n) && n > 0 ? n : 10;
    })();
    const fee = (amount * percent) / 100;
    const amountCents = Math.max(1, Math.round(fee * 100));
    const description = `Deposit fee (${percent}% of $${amount.toFixed(2)})`;

    let successUrl: string;
    let cancelUrl: string;
    const successBaseUrl = body?.success_base_url as string | undefined;
    const cancelBaseUrl = body?.cancel_base_url as string | undefined;
    if (successBaseUrl) {
      successUrl = `${successBaseUrl}${
        successBaseUrl.includes('?') ? '&' : '?'
      }session_id={CHECKOUT_SESSION_ID}`;
      cancelUrl =
        cancelBaseUrl ?? successBaseUrl.replace(/checkout\/success.*$/, 'paywall');
    } else {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const functionsUrl = `${supabaseUrl}/functions/v1`;
      successUrl = `${functionsUrl}/checkout-redirect?session_id={CHECKOUT_SESSION_ID}`;
      cancelUrl = `${functionsUrl}/checkout-redirect?cancel=1`;
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency,
            product_data: { name: description },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: user.id,
      customer_email: user.email ?? undefined,
      metadata: {
        user_id: user.id,
        kind: 'platform_fee',
        request_id: requestId,
        bid_id: bidId,
      },
    });

    return new Response(JSON.stringify({ url: session.url }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});


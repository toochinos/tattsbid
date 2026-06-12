import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
};

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function requestIdFromUrl(url: URL): string | null {
  const fromQuery =
    url.searchParams.get('id') ?? url.searchParams.get('request_id');
  if (fromQuery?.trim()) return fromQuery.trim();

  const segments = url.pathname.split('/').filter(Boolean);
  const last = segments[segments.length - 1];
  if (!last || last === 'tattoo-share') return null;
  return last.trim();
}

function isSocialCrawler(userAgent: string): boolean {
  return /facebookexternalhit|facebot|twitterbot|linkedinbot|whatsapp|slackbot|discordbot|telegrambot|pinterest|googlebot/i.test(
    userAgent,
  );
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const requestId = requestIdFromUrl(url);
  if (!requestId) {
    return new Response('Not found', { status: 404, headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseKey =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseKey) {
    return new Response('Server misconfigured', {
      status: 500,
      headers: corsHeaders,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase
    .from('tattoo_requests')
    .select('id, image_url, starting_bid, description')
    .eq('id', requestId)
    .maybeSingle();

  if (error || !data) {
    return new Response('Not found', { status: 404, headers: corsHeaders });
  }

  const imageUrl = String(data.image_url ?? '').trim();
  const sharePageUrl = `${url.origin}${url.pathname}`;
  const appDeepLink = `tattsbid://tattoo/${requestId}`;
  const title = 'Tattoo listing on TattsBid';
  const bid = data.starting_bid != null ? String(data.starting_bid) : '';
  const description =
    bid !== ''
      ? `Starting bid $${bid} — bid on TattsBid`
      : 'Bid on this tattoo on TattsBid';
  const ogImage =
    imageUrl.startsWith('http') ? imageUrl : 'https://tattsbid.com/logo.png';

  const userAgent = req.headers.get('user-agent') ?? '';
  const crawler = isSocialCrawler(userAgent);
  const redirectTag = crawler
    ? ''
    : `<meta http-equiv="refresh" content="0;url=${escapeHtml(appDeepLink)}" />`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}" />
<meta property="og:title" content="${escapeHtml(title)}" />
<meta property="og:description" content="${escapeHtml(description)}" />
<meta property="og:site_name" content="TattsBid" />
<meta property="og:image" content="${escapeHtml(ogImage)}" />
<meta property="og:image:secure_url" content="${escapeHtml(ogImage)}" />
<meta property="og:type" content="website" />
<meta property="og:url" content="${escapeHtml(sharePageUrl)}" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="${escapeHtml(title)}" />
<meta name="twitter:description" content="${escapeHtml(description)}" />
<meta name="twitter:image" content="${escapeHtml(ogImage)}" />
${redirectTag}
</head>
<body>
<p><a href="${escapeHtml(appDeepLink)}">Open in TattsBid</a></p>
<img src="${escapeHtml(ogImage)}" alt="Tattoo listing" style="max-width:100%;height:auto;" />
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  });
});

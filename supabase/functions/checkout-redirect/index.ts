// Handles Stripe success/cancel redirects. Returns HTML that redirects to the app.
// success: ?session_id=xxx
// cancel: ?cancel=1
// Set APP_SCHEME (e.g. saasapp) for deep link. Default: saasapp

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
};

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const sessionId = url.searchParams.get('session_id');
  const cancel = url.searchParams.get('cancel');
  const scheme = Deno.env.get('APP_SCHEME') ?? 'saasapp';

  let redirectTo: string;
  if (sessionId) {
    redirectTo = `${scheme}://checkout/success?session_id=${encodeURIComponent(sessionId)}`;
  } else if (cancel) {
    redirectTo = `${scheme}://checkout/cancel`;
  } else {
    redirectTo = `${scheme}://checkout/cancel`;
  }

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0;url=${redirectTo}">
  <script>window.location.href="${redirectTo}";</script>
  <title>Redirecting...</title>
</head>
<body>
  <p>Redirecting to app...</p>
  <p><a href="${redirectTo}">Click here if not redirected</a></p>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html',
    },
  });
});

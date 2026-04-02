import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js';

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const token = req.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) {
    return new Response('Unauthorized', { status: 401 });
  }

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (error || !user) {
    return new Response('Invalid user', { status: 401 });
  }

  // 🔥 DELETE USER (THIS IS THE IMPORTANT PART)
  await supabase.auth.admin.deleteUser(user.id);

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const USER_PREFIX_BUCKETS = ['avatars', 'posts', 'portfolio'] as const;
const MEDIA_BUCKETS = ['tattsagram', 'videos'] as const;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-admin-secret',
};

type SupabaseAdmin = ReturnType<typeof createClient>;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function storagePathFromPublicUrl(
  publicUrl: string,
  bucket: string,
): string | null {
  if (!publicUrl?.trim()) return null;
  try {
    const url = new URL(publicUrl.trim());
    const marker = `/storage/v1/object/public/${bucket}/`;
    const idx = url.pathname.indexOf(marker);
    if (idx === -1) return null;
    return decodeURIComponent(url.pathname.slice(idx + marker.length));
  } catch {
    return null;
  }
}

async function collectAllFilesUnderPrefix(
  supabase: SupabaseAdmin,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const out: string[] = [];
  let offset = 0;
  const limit = 1000;
  while (true) {
    const { data: items, error } = await supabase.storage
      .from(bucket)
      .list(prefix, { limit, offset });
    if (error || !items?.length) break;
    for (const item of items) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id == null) {
        out.push(...await collectAllFilesUnderPrefix(supabase, bucket, path));
      } else {
        out.push(path);
      }
    }
    if (items.length < limit) break;
    offset += limit;
  }
  return out;
}

async function purgeUserId(
  supabase: SupabaseAdmin,
  userId: string,
): Promise<{ storageRemoved: number }> {
  const pathsByBucket = new Map<string, Set<string>>();

  const { data: profile } = await supabase
    .from('profiles')
    .select('avatar_url, portfolio_urls')
    .eq('id', userId)
    .maybeSingle();

  if (profile) {
    for (const bucket of USER_PREFIX_BUCKETS) {
      addUrl(pathsByBucket, bucket, storagePathFromPublicUrl(profile.avatar_url ?? '', bucket));
    }
    const portfolio = profile.portfolio_urls;
    if (Array.isArray(portfolio)) {
      for (const entry of portfolio) {
        const url = typeof entry === 'string' ? entry : String(entry ?? '');
        for (const bucket of USER_PREFIX_BUCKETS) {
          addUrl(pathsByBucket, bucket, storagePathFromPublicUrl(url, bucket));
        }
      }
    }
  }

  const { data: requests } = await supabase
    .from('tattoo_requests')
    .select('image_url')
    .eq('user_id', userId);
  for (const row of requests ?? []) {
    addUrl(
      pathsByBucket,
      'posts',
      storagePathFromPublicUrl(row.image_url ?? '', 'posts'),
    );
  }

  const { data: posts } = await supabase
    .from('tattsagram_post')
    .select('media_url, thumbnail_url, video_url')
    .eq('user_id', userId);
  for (const row of posts ?? []) {
    for (const bucket of MEDIA_BUCKETS) {
      addUrl(pathsByBucket, bucket, storagePathFromPublicUrl(row.media_url ?? '', bucket));
      addUrl(pathsByBucket, bucket, storagePathFromPublicUrl(row.thumbnail_url ?? '', bucket));
      addUrl(pathsByBucket, bucket, storagePathFromPublicUrl(row.video_url ?? '', bucket));
    }
  }

  for (const bucket of USER_PREFIX_BUCKETS) {
    if (!pathsByBucket.has(bucket)) pathsByBucket.set(bucket, new Set());
    for (const p of await collectAllFilesUnderPrefix(supabase, bucket, userId)) {
      pathsByBucket.get(bucket)!.add(p);
    }
  }

  let storageRemoved = 0;
  for (const [bucket, pathSet] of pathsByBucket.entries()) {
    const paths = [...pathSet];
    if (!paths.length) continue;
    const batchSize = 100;
    for (let i = 0; i < paths.length; i += batchSize) {
      const batch = paths.slice(i, i + batchSize);
      const { error } = await supabase.storage.from(bucket).remove(batch);
      if (!error) storageRemoved += batch.length;
    }
  }

  await supabase.from('reviews').delete().or(
    `user_id.eq.${userId},artist_id.eq.${userId}`,
  );
  await supabase.from('tattsagram_likes').delete().eq('user_id', userId);
  await supabase.from('tattsagram_post').delete().eq('user_id', userId);
  await supabase.from('live_messages').delete().eq('user_id', userId);
  await supabase.from('live_online').delete().eq('user_id', userId);
  await supabase.from('online_users').delete().eq('user_id', userId);
  await supabase.from('chat_messages').delete().or(
    `sender_id.eq.${userId},receiver_id.eq.${userId}`,
  );
  await supabase.from('contact_unlocks').delete().or(
    `user_id.eq.${userId},artist_id.eq.${userId}`,
  );
  await supabase.from('bids').delete().eq('bidder_id', userId);
  await supabase.from('tattoo_requests').delete().eq('user_id', userId);
  await supabase.from('profiles').delete().eq('id', userId);
  await supabase.auth.admin.deleteUser(userId);

  return { storageRemoved };
}

function addUrl(
  map: Map<string, Set<string>>,
  bucket: string,
  path: string | null,
) {
  if (!path?.trim()) return;
  if (!map.has(bucket)) map.set(bucket, new Set());
  map.get(bucket)!.add(path);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const adminSecret = Deno.env.get('ADMIN_PURGE_SECRET');
  const headerSecret = req.headers.get('x-admin-secret');
  if (!adminSecret || headerSecret !== adminSecret) {
    return jsonResponse({ error: 'Forbidden' }, 403);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server misconfigured' }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: {
    userId?: string;
    email?: string;
    displayName?: string;
  } = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const ids = new Set<string>();

  if (body.userId?.trim()) {
    ids.add(body.userId.trim());
  }

  if (body.email?.trim()) {
    const email = body.email.trim().toLowerCase();
    const { data: authRow } = await supabase.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    for (const u of authRow.users ?? []) {
      if (u.email?.toLowerCase() === email) ids.add(u.id);
    }
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id')
      .ilike('contact_email', email);
    for (const p of profiles ?? []) {
      if (p.id) ids.add(p.id as string);
    }
  }

  if (body.displayName?.trim()) {
    const name = body.displayName.trim();
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, display_name, location')
      .or(
        `display_name.ilike.%Artist-C%,display_name.ilike.%Artist%C%,location.ilike.%Macleod%,contact_email.ilike.artistc@gmail.com`,
      );
    for (const p of profiles ?? []) {
      ids.add(p.id as string);
    }
  }

  if (!ids.size) {
    return jsonResponse({
      error: 'No matching profile/auth user found',
      hint: 'Try displayName: "Artist-C" or email: "artistc@gmail.com"',
    }, 404);
  }

  const results: Record<string, unknown>[] = [];
  for (const userId of ids) {
    try {
      const { storageRemoved } = await purgeUserId(supabase, userId);
      results.push({ userId, ok: true, storageRemoved });
    } catch (e) {
      results.push({
        userId,
        ok: false,
        error: e instanceof Error ? e.message : String(e),
      });
    }
  }

  return jsonResponse({ success: true, purged: results });
});

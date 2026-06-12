import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const USER_PREFIX_BUCKETS = ['avatars', 'posts', 'portfolio'] as const;
const MEDIA_BUCKETS = ['tattsagram', 'videos'] as const;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type SupabaseAdmin = ReturnType<typeof createClient>;

type DeletionLog = {
  step: string;
  detail?: string;
  count?: number;
  ok?: boolean;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function collectObjectPaths(
  supabase: SupabaseAdmin,
  bucket: string,
  prefix: string,
  offset: number,
  limit: number,
): Promise<{ paths: string[]; nextOffset: number | null }> {
  const { data: items, error } = await supabase.storage
    .from(bucket)
    .list(prefix, { limit, offset });

  if (error) {
    console.error(`storage list ${bucket}/${prefix}:`, error.message);
    return { paths: [], nextOffset: null };
  }
  if (!items?.length) {
    return { paths: [], nextOffset: null };
  }

  const paths: string[] = [];
  for (const item of items) {
    const path = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.id == null) {
      const nested = await collectAllFilesUnderPrefix(supabase, bucket, path);
      paths.push(...nested);
    } else {
      paths.push(path);
    }
  }

  const nextOffset = items.length < limit ? null : offset + limit;
  return { paths, nextOffset };
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
    const { paths, nextOffset } = await collectObjectPaths(
      supabase,
      bucket,
      prefix,
      offset,
      limit,
    );
    out.push(...paths);
    if (nextOffset === null) break;
    offset = nextOffset;
  }

  return out;
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

function addPath(
  bucketPaths: Map<string, Set<string>>,
  bucket: string,
  path: string | null,
) {
  if (!path?.trim()) return;
  if (!bucketPaths.has(bucket)) bucketPaths.set(bucket, new Set());
  bucketPaths.get(bucket)!.add(path);
}

async function collectUserMediaPaths(
  supabase: SupabaseAdmin,
  userId: string,
): Promise<Map<string, Set<string>>> {
  const bucketPaths = new Map<string, Set<string>>();

  const { data: profile, error: profileErr } = await supabase
    .from('profiles')
    .select('avatar_url, portfolio_urls')
    .eq('id', userId)
    .maybeSingle();

  if (profileErr) {
    console.error('profiles select:', profileErr.message);
  } else if (profile) {
    for (const bucket of ['avatars', 'posts', 'portfolio'] as const) {
      addPath(
        bucketPaths,
        bucket,
        storagePathFromPublicUrl(profile.avatar_url ?? '', bucket),
      );
    }

    const portfolio = profile.portfolio_urls;
    if (Array.isArray(portfolio)) {
      for (const entry of portfolio) {
        const url = typeof entry === 'string' ? entry : String(entry ?? '');
        for (const bucket of ['portfolio', 'posts', 'avatars'] as const) {
          addPath(bucketPaths, bucket, storagePathFromPublicUrl(url, bucket));
        }
      }
    }
  }

  const { data: requests, error: requestsErr } = await supabase
    .from('tattoo_requests')
    .select('image_url')
    .eq('user_id', userId);

  if (requestsErr) {
    console.error('tattoo_requests select:', requestsErr.message);
  } else {
    for (const row of requests ?? []) {
      addPath(
        bucketPaths,
        'posts',
        storagePathFromPublicUrl(row.image_url ?? '', 'posts'),
      );
    }
  }

  const { data: tattsagramPosts, error: tattsagramErr } = await supabase
    .from('tattsagram_post')
    .select('media_url, thumbnail_url, video_url')
    .eq('user_id', userId);

  if (tattsagramErr) {
    console.error('tattsagram_post select:', tattsagramErr.message);
  } else {
    for (const row of tattsagramPosts ?? []) {
      for (const bucket of MEDIA_BUCKETS) {
        addPath(
          bucketPaths,
          bucket,
          storagePathFromPublicUrl(row.media_url ?? '', bucket),
        );
        addPath(
          bucketPaths,
          bucket,
          storagePathFromPublicUrl(row.thumbnail_url ?? '', bucket),
        );
        addPath(
          bucketPaths,
          bucket,
          storagePathFromPublicUrl(row.video_url ?? '', bucket),
        );
      }
    }
  }

  return bucketPaths;
}

/// Best-effort: never blocks account deletion on storage errors.
async function removePathsBestEffort(
  supabase: SupabaseAdmin,
  bucket: string,
  paths: string[],
  log: DeletionLog[],
): Promise<number> {
  let removed = 0;
  const batchSize = 100;
  for (let i = 0; i < paths.length; i += batchSize) {
    const batch = paths.slice(i, i + batchSize);
    const { error } = await supabase.storage.from(bucket).remove(batch);
    if (error) {
      console.error(`storage remove ${bucket} (batch):`, error.message);
      log.push({
        step: 'storage_warning',
        detail: `${bucket}: ${error.message}`,
        ok: false,
      });
    } else {
      removed += batch.length;
    }
  }
  return removed;
}

async function removeUserStorageBestEffort(
  supabase: SupabaseAdmin,
  userId: string,
  log: DeletionLog[],
): Promise<void> {
  const bucketPaths = await collectUserMediaPaths(supabase, userId);

  for (const bucket of USER_PREFIX_BUCKETS) {
    const prefixPaths = await collectAllFilesUnderPrefix(
      supabase,
      bucket,
      userId,
    );
    if (!bucketPaths.has(bucket)) bucketPaths.set(bucket, new Set());
    for (const path of prefixPaths) {
      bucketPaths.get(bucket)!.add(path);
    }
  }

  let totalRemoved = 0;
  for (const [bucket, pathSet] of bucketPaths.entries()) {
    const paths = [...pathSet];
    if (!paths.length) continue;
    const count = await removePathsBestEffort(supabase, bucket, paths, log);
    totalRemoved += count;
    log.push({ step: 'storage', detail: bucket, count, ok: true });
  }

  log.push({ step: 'storage_total', count: totalRemoved, ok: true });
}

async function deleteWhere(
  supabase: SupabaseAdmin,
  table: string,
  filter: string,
  log: DeletionLog[],
): Promise<void> {
  const { error, count } = await supabase
    .from(table)
    .delete({ count: 'exact' })
    .or(filter);

  if (error) {
    console.error(`delete ${table}:`, error.message);
    log.push({ step: `db_${table}`, detail: error.message, ok: false });
  } else {
    log.push({ step: `db_${table}`, count: count ?? 0, ok: true });
  }
}

/// Explicit user-scoped DB cleanup before auth delete (safety net).
async function purgeUserDatabaseRows(
  supabase: SupabaseAdmin,
  userId: string,
  log: DeletionLog[],
): Promise<void> {
  await deleteWhere(
    supabase,
    'reviews',
    `user_id.eq.${userId},artist_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'tattsagram_likes',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'tattsagram_post',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'live_messages',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'live_online',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'online_users',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'chat_messages',
    `sender_id.eq.${userId},receiver_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'contact_unlocks',
    `user_id.eq.${userId},artist_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'bids',
    `bidder_id.eq.${userId}`,
    log,
  );
  await deleteWhere(
    supabase,
    'tattoo_requests',
    `user_id.eq.${userId}`,
    log,
  );
  await deleteWhere(supabase, 'profiles', `id.eq.${userId}`, log);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('delete-user: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return jsonResponse(
      { error: 'Server misconfigured: missing service role credentials' },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = req.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const {
    data: { user },
    error: userErr,
  } = await supabase.auth.getUser(token);

  if (userErr || !user) {
    console.error('delete-user: invalid token', userErr?.message);
    return jsonResponse({ error: 'Invalid user' }, 401);
  }

  const userId = user.id;
  const log: DeletionLog[] = [];

  console.log(`delete-user: start userId=${userId} email=${user.email ?? ''}`);

  try {
    await removeUserStorageBestEffort(supabase, userId, log);
    await purgeUserDatabaseRows(supabase, userId, log);

    const { error: delErr } = await supabase.auth.admin.deleteUser(userId);

    if (delErr) {
      console.error('delete-user: auth delete failed', delErr.message);
      return jsonResponse(
        {
          error: delErr.message ?? 'Failed to delete auth user',
          step: 'auth',
          userId,
          log,
        },
        500,
      );
    }

    log.push({ step: 'auth', ok: true });
    console.log(`delete-user: success userId=${userId}`, JSON.stringify(log));

    return jsonResponse({ success: true, userId, log });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error('delete-user: unexpected error', message);
    return jsonResponse({ error: message, step: 'unexpected', log }, 500);
  }
});

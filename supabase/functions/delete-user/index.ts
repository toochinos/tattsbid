import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const STORAGE_BUCKETS = ['avatars', 'posts', 'portfolio'] as const;

type SupabaseAdmin = ReturnType<typeof createClient>;

/// Lists one "page" of a storage prefix and returns file paths (recurses into folders).
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

async function removeUserStorage(supabase: SupabaseAdmin, userId: string) {
  for (const bucket of STORAGE_BUCKETS) {
    const paths = await collectAllFilesUnderPrefix(supabase, bucket, userId);
    const batchSize = 100;
    for (let i = 0; i < paths.length; i += batchSize) {
      const batch = paths.slice(i, i + batchSize);
      const { error } = await supabase.storage.from(bucket).remove(batch);
      if (error) {
        console.error(`storage remove ${bucket}:`, error.message);
      }
    }
  }
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const token = req.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const {
    data: { user },
    error: userErr,
  } = await supabase.auth.getUser(token);

  if (userErr || !user) {
    return new Response(JSON.stringify({ error: 'Invalid user' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const userId = user.id;

  try {
    await removeUserStorage(supabase, userId);
  } catch (e) {
    console.error('removeUserStorage:', e);
  }

  const { error: reviewsErr } = await supabase
    .from('reviews')
    .delete()
    .or(`user_id.eq.${userId},artist_id.eq.${userId}`);

  if (reviewsErr) {
    console.error('reviews delete (table may be absent):', reviewsErr.message);
  }

  const { error: delErr } = await supabase.auth.admin.deleteUser(userId);

  if (delErr) {
    return new Response(
      JSON.stringify({ error: delErr.message ?? 'Failed to delete user' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

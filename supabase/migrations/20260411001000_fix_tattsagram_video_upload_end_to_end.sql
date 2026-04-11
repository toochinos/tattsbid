-- End-to-end Tattsagram media fix:
-- - canonical table name: public.tattsagram_post
-- - media_type includes video
-- - storage bucket + policies support authenticated image/video uploads

create extension if not exists pgcrypto;

create table if not exists public.tattsagram_post (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_url text not null,
  media_type text not null check (media_type in ('image', 'video')),
  caption text not null default '',
  created_at timestamptz not null default now()
);

-- Optional columns used by UI; ensure they exist.
alter table public.tattsagram_post
  add column if not exists artist_name text not null default '',
  add column if not exists location text not null default '',
  add column if not exists thumbnail_url text;

-- If an older plural table exists, backfill data into canonical singular table.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'tattsagram_posts'
  ) then
    insert into public.tattsagram_post (
      id, user_id, media_url, media_type, caption, created_at, artist_name, location, thumbnail_url
    )
    select
      p.id,
      p.user_id,
      p.media_url,
      case when p.media_type = 'video' then 'video' else 'image' end,
      coalesce(p.caption, ''),
      coalesce(p.created_at, now()),
      coalesce(p.artist_name, ''),
      coalesce(p.location, ''),
      p.thumbnail_url
    from public.tattsagram_posts p
    on conflict (id) do nothing;
  end if;
end $$;

alter table public.tattsagram_post enable row level security;

create index if not exists idx_tattsagram_post_created_at
  on public.tattsagram_post (created_at desc);

drop policy if exists "Tattsagram post public read" on public.tattsagram_post;
create policy "Tattsagram post public read"
  on public.tattsagram_post
  for select
  to public
  using (true);

drop policy if exists "Tattsagram post insert own" on public.tattsagram_post;
create policy "Tattsagram post insert own"
  on public.tattsagram_post
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Tattsagram post update own" on public.tattsagram_post;
create policy "Tattsagram post update own"
  on public.tattsagram_post
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Tattsagram post delete own" on public.tattsagram_post;
create policy "Tattsagram post delete own"
  on public.tattsagram_post
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Ensure posts bucket exists and accepts image + video.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'posts',
  'posts',
  true,
  52428800, -- 50MB
  array['image/jpeg', 'image/png', 'video/mp4', 'video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload own posts" on storage.objects;
create policy "Users can upload own posts"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Posts are publicly accessible" on storage.objects;
create policy "Posts are publicly accessible"
  on storage.objects
  for select
  to public
  using (bucket_id = 'posts');

drop policy if exists "Users can update own posts" on storage.objects;
create policy "Users can update own posts"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can delete own posts" on storage.objects;
create policy "Users can delete own posts"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Tattsagram media posts: supports image + video.
-- Adds table for feed metadata and updates posts bucket MIME/size for video uploads.

create table if not exists public.tattsagram_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_url text not null,
  media_type text not null check (media_type in ('image', 'video')),
  thumbnail_url text,
  artist_name text not null default '',
  location text not null default '',
  caption text not null default '',
  created_at timestamptz not null default now()
);

alter table public.tattsagram_posts enable row level security;

create index if not exists idx_tattsagram_posts_created_at
  on public.tattsagram_posts (created_at desc);

drop policy if exists "Tattsagram posts are publicly readable" on public.tattsagram_posts;
create policy "Tattsagram posts are publicly readable"
  on public.tattsagram_posts for select
  to public
  using (true);

drop policy if exists "Authenticated users can insert own Tattsagram posts" on public.tattsagram_posts;
create policy "Authenticated users can insert own Tattsagram posts"
  on public.tattsagram_posts for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own Tattsagram posts" on public.tattsagram_posts;
create policy "Users can update own Tattsagram posts"
  on public.tattsagram_posts for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own Tattsagram posts" on public.tattsagram_posts;
create policy "Users can delete own Tattsagram posts"
  on public.tattsagram_posts for delete
  to authenticated
  using (auth.uid() = user_id);

-- Update storage bucket limits/mime to support video uploads (mp4, mov).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'posts',
  'posts',
  true,
  52428800,
  array['image/jpeg', 'image/png', 'video/mp4', 'video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Reel-style metadata: explicit video URL, content type, public visibility.

alter table public.tattsagram_post
  add column if not exists video_url text,
  add column if not exists type text not null default 'media',
  add column if not exists is_public boolean not null default true;

update public.tattsagram_post
set
  video_url = media_url,
  type = 'reel'
where media_type = 'video'
  and (video_url is null or trim(video_url) = '');

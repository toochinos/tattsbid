-- Public bucket for Tattsagram video files at videos/…
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tattsagram',
  'tattsagram',
  true,
  52428800, -- 50MB
  array['video/mp4', 'video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Tattsagram storage public read" on storage.objects;
create policy "Tattsagram storage public read"
  on storage.objects
  for select
  to public
  using (bucket_id = 'tattsagram');

drop policy if exists "Tattsagram authenticated upload videos folder" on storage.objects;
create policy "Tattsagram authenticated upload videos folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'tattsagram'
    and (storage.foldername(name))[1] = 'videos'
  );

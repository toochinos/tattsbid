-- Tattsagram STEP 2: dedicated `videos` bucket (path keys like `videos/<ts>.mp4`)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'videos',
  'videos',
  true,
  52428800, -- 50MB
  array['video/mp4', 'video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Videos bucket public read" on storage.objects;
create policy "Videos bucket public read"
  on storage.objects
  for select
  to public
  using (bucket_id = 'videos');

drop policy if exists "Videos bucket authenticated upload videos prefix" on storage.objects;
create policy "Videos bucket authenticated upload videos prefix"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = 'videos'
  );

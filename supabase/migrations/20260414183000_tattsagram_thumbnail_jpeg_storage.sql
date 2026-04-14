-- JPEG posters for video rows (client uploads to thumbnails/… alongside videos/…).

update storage.buckets
set allowed_mime_types = array['video/mp4', 'video/quicktime', 'image/jpeg']
where id = 'tattsagram';

drop policy if exists "Tattsagram authenticated upload videos folder" on storage.objects;
create policy "Tattsagram authenticated upload videos folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'tattsagram'
    and (storage.foldername(name))[1] in ('videos', 'thumbnails')
  );

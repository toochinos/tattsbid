-- RLS policies for avatars bucket (profile pictures).
-- Create the bucket first in Supabase Dashboard → Storage:
-- New bucket "avatars", public, allowed MIME: image/*, max size: 2MB.

-- Allow authenticated users to upload to their own folder (avatars/{user_id}/*).
create policy "Users can upload own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow public read (bucket is public).
create policy "Avatar images are publicly accessible"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

-- Allow users to update/delete their own avatar.
create policy "Users can update own avatar"
  on storage.objects for update
  to authenticated
  using ((storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars');

create policy "Users can delete own avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

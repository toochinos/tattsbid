-- RLS policies for posts bucket (customer reference photos).
-- Create the bucket first in Supabase Dashboard → Storage:
-- New bucket "posts", public, allowed MIME: image/*, max size: 5MB.

-- Allow authenticated users to upload to their own folder (posts/{user_id}/*).
create policy "Users can upload own posts"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow public read (bucket is public).
create policy "Posts are publicly accessible"
  on storage.objects for select
  to public
  using (bucket_id = 'posts');

-- Allow users to delete their own posts.
create policy "Users can delete own posts"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

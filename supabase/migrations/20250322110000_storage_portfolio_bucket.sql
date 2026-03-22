-- Dedicated bucket for tattoo artist portfolio images (see ProfileService.uploadPortfolioImage).
-- Create bucket if missing, then RLS: users may only read/write under {auth.uid()}/...

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'portfolio',
    'portfolio',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Drop if re-running migration (idempotent policy names).
drop policy if exists "Users can upload own portfolio images" on storage.objects;
drop policy if exists "Portfolio images are publicly readable" on storage.objects;
drop policy if exists "Users can update own portfolio images" on storage.objects;
drop policy if exists "Users can delete own portfolio images" on storage.objects;

create policy "Users can upload own portfolio images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Portfolio images are publicly readable"
  on storage.objects for select
  to public
  using (bucket_id = 'portfolio');

create policy "Users can update own portfolio images"
  on storage.objects for update
  to authenticated
  using ((storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'portfolio');

create policy "Users can delete own portfolio images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Fix delete policy: ensure authenticated users can delete their own tattoo requests.
drop policy if exists "Users can delete own tattoo requests" on public.tattoo_requests;

create policy "Users can delete own tattoo requests"
  on public.tattoo_requests for delete
  to authenticated
  using ((select auth.uid()) = user_id);

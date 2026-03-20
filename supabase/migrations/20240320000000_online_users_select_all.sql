-- Allow authenticated users to view all online users (for Chat).
create policy "Authenticated users can view online users"
  on public.online_users for select
  to authenticated
  using (true);

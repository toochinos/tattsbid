-- Allow authenticated users to view display_name of any profile (for showing customer names on Explore).
create policy "Authenticated users can view profile display names"
  on public.profiles for select
  to authenticated
  using (true);

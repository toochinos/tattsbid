-- Restrict bid placement to tattoo artists only.
drop policy if exists "Authenticated users can place bids" on public.bids;
drop policy if exists "Tattoo artists can place bids" on public.bids;

create policy "Tattoo artists can place bids"
  on public.bids for insert
  to authenticated
  with check (
    bidder_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.user_type = 'tattoo_artist'
    )
    and exists (
      select 1 from public.tattoo_requests tr
      where tr.id = request_id and tr.status = 'open'
    )
  );

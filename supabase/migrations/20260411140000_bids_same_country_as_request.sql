-- Tattoo artists may only insert bids when profile country matches the request country
-- (case-insensitive, both non-empty). Aligns with app [BidService.placeBid].

drop policy if exists "Tattoo artists can place bids" on public.bids;

create policy "Tattoo artists can place bids"
  on public.bids for insert
  to authenticated
  with check (
    bidder_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      inner join public.tattoo_requests tr on tr.id = request_id
      where p.id = auth.uid()
        and p.user_type = 'tattoo_artist'
        and tr.status = 'open'
        and p.country is not null
        and trim(p.country) <> ''
        and tr.country is not null
        and trim(tr.country) <> ''
        and lower(trim(p.country)) = lower(trim(tr.country))
    )
  );

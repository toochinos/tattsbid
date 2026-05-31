-- Artists bid on customer job posts; customers bid on artist promo posts.

drop policy if exists "Tattoo artists can place bids" on public.bids;

create policy "Tattoo artists bid on customer requests"
  on public.bids for insert
  to authenticated
  with check (
    bidder_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      inner join public.tattoo_requests tr on tr.id = request_id
      inner join public.profiles poster on poster.id = tr.user_id
      where p.id = auth.uid()
        and p.user_type = 'tattoo_artist'
        and tr.status = 'open'
        and coalesce(poster.user_type, 'customer') <> 'tattoo_artist'
        and p.country is not null
        and trim(p.country) <> ''
        and tr.country is not null
        and trim(tr.country) <> ''
        and lower(trim(p.country)) = lower(trim(tr.country))
    )
  );

create policy "Customers bid on artist promos"
  on public.bids for insert
  to authenticated
  with check (
    bidder_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      inner join public.tattoo_requests tr on tr.id = request_id
      inner join public.profiles poster on poster.id = tr.user_id
      where p.id = auth.uid()
        and p.user_type = 'customer'
        and tr.status = 'open'
        and poster.user_type = 'tattoo_artist'
    )
  );

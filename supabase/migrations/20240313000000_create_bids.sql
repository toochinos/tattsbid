-- Bids on tattoo requests. Artists place bids with an amount.
create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.tattoo_requests(id) on delete cascade,
  bidder_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(10, 2) not null,
  created_at timestamptz default now(),
  unique (request_id, bidder_id)
);

create index if not exists idx_bids_request_id on public.bids(request_id);
create index if not exists idx_bids_created_at on public.bids(created_at desc);

alter table public.bids enable row level security;

-- View bids on requests you can see (open requests or your own).
create policy "Users can view bids on visible requests"
  on public.bids for select
  using (
    exists (
      select 1 from public.tattoo_requests tr
      where tr.id = request_id
        and (tr.status = 'open' or tr.user_id = auth.uid())
    )
  );

-- Only tattoo artists can place bids on open requests.
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

-- Users can update or delete their own bids.
create policy "Users can update own bids"
  on public.bids for update
  using (bidder_id = auth.uid());

create policy "Users can delete own bids"
  on public.bids for delete
  using (bidder_id = auth.uid());

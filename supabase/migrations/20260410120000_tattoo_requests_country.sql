-- Country for Explore filtering and new posts (matches profile country names).
alter table public.tattoo_requests
  add column if not exists country text;

create index if not exists idx_tattoo_requests_country
  on public.tattoo_requests (country);

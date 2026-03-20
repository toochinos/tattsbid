-- Tattoo requests: customer reference photo + description + starting bid.
-- Customers create a request; artists can bid on it.

create table if not exists public.tattoo_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text not null,
  description text,
  starting_bid numeric(10, 2) not null default 0,
  status text not null default 'open' check (status in ('open', 'in_progress', 'completed')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index for listing by user and status.
create index if not exists idx_tattoo_requests_user_id on public.tattoo_requests(user_id);
create index if not exists idx_tattoo_requests_status on public.tattoo_requests(status);

-- RLS: users can read and manage their own requests.
alter table public.tattoo_requests enable row level security;

create policy "Users can view own tattoo requests"
  on public.tattoo_requests for select
  using (auth.uid() = user_id);

create policy "Users can insert own tattoo requests"
  on public.tattoo_requests for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tattoo requests"
  on public.tattoo_requests for update
  using (auth.uid() = user_id);

create policy "Users can delete own tattoo requests"
  on public.tattoo_requests for delete
  using (auth.uid() = user_id);

create policy "Users can view open tattoo requests"
  on public.tattoo_requests for select
  using (status = 'open');

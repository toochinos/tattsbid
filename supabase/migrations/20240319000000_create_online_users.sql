-- Track user presence (last_seen) for online status.
create table if not exists public.online_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seen timestamptz not null default now()
);

alter table public.online_users enable row level security;

-- Users can upsert their own row.
create policy "Users can upsert own online status"
  on public.online_users for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

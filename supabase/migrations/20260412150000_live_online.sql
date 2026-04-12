-- Tattsagram: one row per user for “online” / last-seen heartbeat.

create table if not exists public.live_online (
  user_id uuid primary key references auth.users (id) on delete cascade,
  username text not null default '',
  last_seen timestamptz not null default now()
);

create index if not exists idx_live_online_last_seen
  on public.live_online (last_seen desc);

alter table public.live_online enable row level security;

drop policy if exists "live_online select authenticated" on public.live_online;
create policy "live_online select authenticated"
  on public.live_online
  for select
  to authenticated
  using (true);

drop policy if exists "live_online insert own" on public.live_online;
create policy "live_online insert own"
  on public.live_online
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "live_online update own" on public.live_online;
create policy "live_online update own"
  on public.live_online
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

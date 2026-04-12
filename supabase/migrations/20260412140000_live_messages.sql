-- Tattsagram live chat: broadcast messages for authenticated users.

create table if not exists public.live_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  username text not null default '',
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_live_messages_created_at
  on public.live_messages (created_at desc);

alter table public.live_messages enable row level security;

drop policy if exists "Live messages select authenticated" on public.live_messages;
create policy "Live messages select authenticated"
  on public.live_messages
  for select
  to authenticated
  using (true);

drop policy if exists "Live messages insert own" on public.live_messages;
create policy "Live messages insert own"
  on public.live_messages
  for insert
  to authenticated
  with check (auth.uid() = user_id);

alter publication supabase_realtime add table public.live_messages;

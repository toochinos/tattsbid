-- Chat room messages: one shared room for all users.
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_created_at_idx
  on public.chat_messages (created_at);

alter table public.chat_messages enable row level security;

-- Authenticated users can read all messages.
create policy "Authenticated users can view chat messages"
  on public.chat_messages for select
  to authenticated
  using (true);

-- Authenticated users can insert their own messages.
create policy "Authenticated users can insert chat messages"
  on public.chat_messages for insert
  to authenticated
  with check (auth.uid() = user_id);

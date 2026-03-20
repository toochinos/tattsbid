-- Run this in Supabase Dashboard: SQL Editor → New query → paste and Run
-- Creates the chat_messages table for direct messaging (sender_id, receiver_id).
-- If you have the old schema (user_id), run the "Migrate from shared room" block at the end first.

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_created_at_idx
  on public.chat_messages (created_at);

create index if not exists chat_messages_sender_receiver_idx
  on public.chat_messages (sender_id, receiver_id);

alter table public.chat_messages enable row level security;

-- Users can read messages where they are sender or receiver.
create policy "Users can view their direct messages"
  on public.chat_messages for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Users can insert messages as sender.
create policy "Users can insert direct messages"
  on public.chat_messages for insert
  to authenticated
  with check (auth.uid() = sender_id);

-- Enable realtime so all clients see new messages.
alter publication supabase_realtime add table public.chat_messages;

-- Add message column for inserts using 'message' key.
alter table public.chat_messages add column if not exists message text;

-- Migrate from shared room (user_id) to direct messaging (sender_id, receiver_id):
-- Run this block only if chat_messages already exists with user_id.
/*
alter table public.chat_messages add column if not exists sender_id uuid references auth.users(id) on delete cascade;
alter table public.chat_messages add column if not exists receiver_id uuid references auth.users(id) on delete cascade;
update public.chat_messages set sender_id = user_id, receiver_id = user_id where sender_id is null and user_id is not null;
drop policy if exists "Authenticated users can view chat messages" on public.chat_messages;
drop policy if exists "Authenticated users can insert chat messages" on public.chat_messages;
create policy "Users can view their direct messages" on public.chat_messages for select to authenticated using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Users can insert direct messages" on public.chat_messages for insert to authenticated with check (auth.uid() = sender_id);
*/

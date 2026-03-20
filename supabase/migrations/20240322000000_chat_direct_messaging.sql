-- Migrate chat_messages from shared room (user_id) to direct messaging (sender_id, receiver_id).

alter table public.chat_messages
  add column if not exists sender_id uuid references auth.users(id) on delete cascade,
  add column if not exists receiver_id uuid references auth.users(id) on delete cascade;

-- Backfill existing rows: treat user_id as both sender and receiver.
update public.chat_messages
set sender_id = user_id, receiver_id = user_id
where sender_id is null and user_id is not null;

-- Update RLS for direct messaging.
drop policy if exists "Authenticated users can view chat messages" on public.chat_messages;
create policy "Users can view their direct messages"
  on public.chat_messages for select
  to authenticated
  using (
    auth.uid() = sender_id or auth.uid() = receiver_id
    or (sender_id is null and auth.uid() = user_id)
  );

drop policy if exists "Authenticated users can insert chat messages" on public.chat_messages;
create policy "Users can insert direct messages"
  on public.chat_messages for insert
  to authenticated
  with check (auth.uid() = sender_id);

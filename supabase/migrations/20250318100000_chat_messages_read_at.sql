-- Read receipts: null read_at = unread for the receiver.

alter table public.chat_messages
  add column if not exists read_at timestamptz;

create index if not exists chat_messages_receiver_unread_idx
  on public.chat_messages (receiver_id)
  where read_at is null;

-- Receivers can set read_at on messages they received.
create policy "Receivers can mark messages as read"
  on public.chat_messages for update
  to authenticated
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

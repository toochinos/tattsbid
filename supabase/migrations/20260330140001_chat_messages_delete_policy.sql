-- Let users delete chat rows they sent or received (client-side cleanup).

drop policy if exists "Users can delete their chat messages" on public.chat_messages;
create policy "Users can delete their chat messages"
  on public.chat_messages for delete
  to authenticated
  using (
    auth.uid() = sender_id
    or auth.uid() = receiver_id
    or (sender_id is null and receiver_id is null and auth.uid() = user_id)
  );

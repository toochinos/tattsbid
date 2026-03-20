-- Enable realtime for chat_messages so all clients see new messages.
alter publication supabase_realtime add table public.chat_messages;

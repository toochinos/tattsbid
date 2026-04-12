-- [live_messages.message] must be PostgreSQL TEXT (UTF-8), not bytea/json/varchar hacks.
-- No-op if already `text`.
alter table public.live_messages
  alter column message type text using message::text;

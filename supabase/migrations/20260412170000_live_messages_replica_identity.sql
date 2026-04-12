-- Helps Realtime broadcast row payloads reliably for [live_messages] subscribers.
alter table public.live_messages replica identity full;

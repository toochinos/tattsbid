-- Enable realtime so [LiveOnlineService.onlineUsers] stream receives updates.
alter publication supabase_realtime add table public.live_online;

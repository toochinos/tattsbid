-- Enable realtime for tattoo_requests so all clients see inserts/deletes.
-- Run in Supabase Dashboard → SQL Editor, or: Database → Replication → toggle tattoo_requests.
alter publication supabase_realtime add table public.tattoo_requests;

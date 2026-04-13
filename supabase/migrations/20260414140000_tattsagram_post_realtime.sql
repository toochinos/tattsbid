-- STEP 3: broadcast [tattsagram_post] inserts to Realtime clients (e.g. Tattsagram feed).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tattsagram_post'
  ) then
    alter publication supabase_realtime add table public.tattsagram_post;
  end if;
end $$;

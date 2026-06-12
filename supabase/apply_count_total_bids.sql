-- Run once in Supabase Dashboard → SQL Editor.
-- Fixes Developer Dashboard "Total Bids = 0" when SELECT COUNT(*) FROM bids is correct.

create or replace function public.count_total_bids()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint from public.bids;
$$;

grant execute on function public.count_total_bids() to authenticated;

comment on function public.count_total_bids() is
  'Developer dashboard: SELECT COUNT(*) FROM bids (bypasses RLS).';

-- Verify:
--   select public.count_total_bids();

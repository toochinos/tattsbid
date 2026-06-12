-- Authoritative bid count for Developer Dashboard (bypasses bids RLS).

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
  'Developer dashboard: SELECT COUNT(*) FROM bids.';

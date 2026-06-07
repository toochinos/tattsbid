-- Remove online_users rows that have not heartbeated recently (housekeeping).
-- Dashboard counts already filter last_seen >= now() - 2 minutes; this keeps the table lean.

create or replace function public.prune_stale_online_users()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.online_users
  where last_seen < (now() at time zone 'utc') - interval '2 minutes';
end;
$$;

comment on function public.prune_stale_online_users() is
  'Deletes online_users rows older than 2 minutes (matches dashboard presence window).';

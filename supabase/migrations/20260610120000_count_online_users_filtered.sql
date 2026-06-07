-- Filtered presence counts (server UTC). Never count(*) without last_seen filter.

create or replace function public.count_online_users()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.online_users
  where last_seen > timezone('utc', now()) - interval '2 minutes';
$$;

create or replace function public.count_active_users_today()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.online_users
  where last_seen > timezone('utc', now()) - interval '24 hours';
$$;

comment on function public.count_online_users() is
  'Online Users: last_seen > now() - 2 minutes (UTC).';

comment on function public.count_active_users_today() is
  'Active Users Today: last_seen > now() - 24 hours (UTC).';

grant execute on function public.count_online_users() to authenticated;
grant execute on function public.count_active_users_today() to authenticated;

-- Keep get_dashboard_stats in sync (uses same filters, not raw count(*)).
create or replace function public.get_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_total_users bigint;
  v_total_customers bigint;
  v_total_artists bigint;
  v_new_users_this_week bigint;
  v_active_users_today bigint;
  v_users_online_now bigint;
  v_total_tattoo_requests bigint;
begin
  select count(*)::bigint into v_total_users from public.profiles;

  select count(*)::bigint into v_total_customers
  from public.profiles
  where lower(trim(coalesce(user_type, ''))) = 'customer';

  select count(*)::bigint into v_total_artists
  from public.profiles
  where lower(trim(coalesce(user_type, ''))) in ('tattoo_artist', 'tattoo artist');

  select count(*)::bigint into v_new_users_this_week
  from public.profiles
  where created_at >= v_now - interval '7 days';

  select public.count_active_users_today() into v_active_users_today;
  select public.count_online_users() into v_users_online_now;

  select count(*)::bigint into v_total_tattoo_requests
  from public.tattoo_requests;

  return jsonb_build_object(
    'total_users', v_total_users,
    'total_customers', v_total_customers,
    'total_artists', v_total_artists,
    'new_users_this_week', v_new_users_this_week,
    'active_users_today', v_active_users_today,
    'users_online_now', v_users_online_now,
    'online_users', v_users_online_now,
    'online_users_now', v_users_online_now,
    'total_tattoo_requests', v_total_tattoo_requests,
    'generated_at', v_now
  );
end;
$$;

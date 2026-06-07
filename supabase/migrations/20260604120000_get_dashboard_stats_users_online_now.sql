-- Add users_online_now to get_dashboard_stats (online_users seen in last 2 minutes).

create or replace function public.get_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_total_users bigint;
  v_total_customers bigint;
  v_total_artists bigint;
  v_new_users_this_week bigint;
  v_active_users_today bigint;
  v_users_online_now bigint;
  v_total_tattoo_requests bigint;
begin
  select count(*)::bigint into v_total_users
  from public.profiles;

  select count(*)::bigint into v_total_customers
  from public.profiles
  where lower(trim(coalesce(user_type, ''))) = 'customer';

  select count(*)::bigint into v_total_artists
  from public.profiles
  where lower(trim(coalesce(user_type, ''))) in ('tattoo_artist', 'tattoo artist');

  select count(*)::bigint into v_new_users_this_week
  from public.profiles
  where created_at >= timezone('utc', now()) - interval '7 days';

  select count(*)::bigint into v_active_users_today
  from public.profiles
  where last_seen >= timezone('utc', now()) - interval '24 hours';

  select count(*)::bigint into v_users_online_now
  from public.online_users
  where last_seen >= timezone('utc', now()) - interval '2 minutes';

  select count(*)::bigint into v_total_tattoo_requests
  from public.tattoo_requests;

  return jsonb_build_object(
    'total_users', v_total_users,
    'total_customers', v_total_customers,
    'total_artists', v_total_artists,
    'new_users_this_week', v_new_users_this_week,
    'active_users_today', v_active_users_today,
    'users_online_now', v_users_online_now,
    'total_tattoo_requests', v_total_tattoo_requests
  );
end;
$$;

comment on function public.get_dashboard_stats() is
  'Developer dashboard metrics including users online in the last 2 minutes.';

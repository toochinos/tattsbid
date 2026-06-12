-- Add total_bids (and total_promotions) to get_dashboard_stats JSON.
-- Superseded by 20260615120000_get_dashboard_stats_inline_counts.sql (inline counts).

drop function if exists public.get_dashboard_stats();

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
  v_total_bids bigint;
  v_total_promotions bigint;
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

  select count(*)::bigint into v_total_bids
  from public.bids;

  select count(*)::bigint into v_total_promotions
  from public.tattoo_requests tr
  inner join public.profiles p on p.id = tr.user_id
  where lower(trim(coalesce(p.user_type, ''))) in ('tattoo_artist', 'tattoo artist');

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
    'total_bids', v_total_bids,
    'total_promotions', v_total_promotions,
    'generated_at', v_now
  );
end;
$$;

comment on function public.get_dashboard_stats() is
  'Developer dashboard aggregates. total_bids = count(bids). total_promotions = artist tattoo_requests.';

revoke all on function public.get_dashboard_stats() from public;
grant execute on function public.get_dashboard_stats() to authenticated;

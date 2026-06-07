-- Extend get_dashboard_stats() with weekly signups, active users, and tattoo request totals.
-- Uses profiles.user_type (customer | tattoo_artist) and profiles.created_at / last_seen.

-- ---------------------------------------------------------------------------
-- 1. profiles.last_seen (for Active Users Today)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists last_seen timestamptz;

comment on column public.profiles.last_seen is
  'Last app activity; synced from online_users / live_online. Used by get_dashboard_stats().';

create index if not exists idx_profiles_created_at
  on public.profiles (created_at desc);

create index if not exists idx_profiles_last_seen
  on public.profiles (last_seen desc nulls last)
  where last_seen is not null;

-- Backfill last_seen from presence tables when available.
update public.profiles p
set last_seen = src.max_seen
from (
  select user_id, max(last_seen) as max_seen
  from (
    select user_id, last_seen from public.online_users
    union all
    select user_id, last_seen from public.live_online
  ) combined
  group by user_id
) src
where p.id = src.user_id
  and (p.last_seen is null or p.last_seen < src.max_seen);

-- Keep profiles.last_seen in sync with online_users heartbeats.
create or replace function public.touch_profile_last_seen(p_user_id uuid, p_seen timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set
    last_seen = greatest(coalesce(last_seen, p_seen), p_seen),
    updated_at = timezone('utc', now())
  where id = p_user_id;
end;
$$;

create or replace function public.trg_online_users_touch_profile_last_seen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.touch_profile_last_seen(new.user_id, new.last_seen);
  return new;
end;
$$;

drop trigger if exists online_users_touch_profile_last_seen on public.online_users;
create trigger online_users_touch_profile_last_seen
  after insert or update of last_seen on public.online_users
  for each row
  execute function public.trg_online_users_touch_profile_last_seen();

create or replace function public.trg_live_online_touch_profile_last_seen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.touch_profile_last_seen(new.user_id, new.last_seen);
  return new;
end;
$$;

drop trigger if exists live_online_touch_profile_last_seen on public.live_online;
create trigger live_online_touch_profile_last_seen
  after insert or update of last_seen on public.live_online
  for each row
  execute function public.trg_live_online_touch_profile_last_seen();

-- ---------------------------------------------------------------------------
-- 2. RPC: get_dashboard_stats (password-gated in app; no admin role check)
-- ---------------------------------------------------------------------------

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

  select count(*)::bigint into v_total_tattoo_requests
  from public.tattoo_requests;

  return jsonb_build_object(
    'total_users', v_total_users,
    'total_customers', v_total_customers,
    'total_artists', v_total_artists,
    'new_users_this_week', v_new_users_this_week,
    'active_users_today', v_active_users_today,
    'total_tattoo_requests', v_total_tattoo_requests
  );
end;
$$;

comment on function public.get_dashboard_stats() is
  'Developer dashboard metrics: users by user_type, weekly signups, 24h active, tattoo_requests count.';

revoke all on function public.get_dashboard_stats() from public;
grant execute on function public.get_dashboard_stats() to authenticated;

-- Developer Dashboard: profiles.last_seen, admin roles, stats RPC, presence sync.
-- Run in Supabase SQL Editor (or via supabase db push).
--
-- Existing schema reused:
--   public.profiles (id, user_type, role, created_at, display_name, avatar_url, …)
--   public.tattoo_requests
--   public.contact_unlocks (deposit_amount, status='paid') → platform revenue
--   public.online_users.last_seen, public.live_online.last_seen → synced to profiles.last_seen

-- ---------------------------------------------------------------------------
-- 1. profiles.last_seen + role constraint (customer | artist | admin | super_admin)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists last_seen timestamptz;

comment on column public.profiles.last_seen is
  'Last app activity; updated from online_users / live_online heartbeats. Used for Active Users Today.';

comment on column public.profiles.role is
  'Account role: customer | artist | admin | super_admin. Legacy user_type (tattoo_artist/customer) still used by app bidding rules.';

-- Normalize legacy role values before check constraint
update public.profiles
set role = 'artist'
where role is not null
  and lower(trim(role)) in ('tattoo_artist', 'tattoo artist');

update public.profiles
set role = 'customer'
where role is not null
  and lower(trim(role)) in ('client');

-- Backfill role from user_type when role is unset
update public.profiles
set role = 'artist'
where role is null
  and lower(trim(coalesce(user_type, ''))) in ('tattoo_artist', 'tattoo artist', 'artist');

update public.profiles
set role = 'customer'
where role is null
  and lower(trim(coalesce(user_type, ''))) in ('customer', 'client');

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (
    role is null
    or lower(trim(role)) in (
      'customer',
      'artist',
      'admin',
      'super_admin'
    )
  );

create index if not exists idx_profiles_created_at
  on public.profiles (created_at desc);

create index if not exists idx_profiles_last_seen
  on public.profiles (last_seen desc nulls last)
  where last_seen is not null;

create index if not exists idx_profiles_role
  on public.profiles (lower(trim(role)))
  where role is not null;

create index if not exists idx_contact_unlocks_revenue
  on public.contact_unlocks (created_at desc)
  where status = 'paid' and deposit_amount is not null;

-- ---------------------------------------------------------------------------
-- 2. Role helpers (marketplace vs dashboard)
-- ---------------------------------------------------------------------------

create or replace function public.profile_role_normalized(p public.profiles)
returns text
language sql
stable
as $$
  select case
    when p.role is not null and trim(p.role) <> ''
      then lower(trim(p.role))
    when lower(trim(coalesce(p.user_type, ''))) in ('tattoo_artist', 'tattoo artist', 'artist')
      then 'artist'
    when lower(trim(coalesce(p.user_type, ''))) in ('customer', 'client')
      then 'customer'
    else 'unknown'
  end;
$$;

comment on function public.profile_role_normalized(public.profiles) is
  'Resolved role for UI: prefers profiles.role, falls back to user_type.';

create or replace function public.is_dashboard_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(trim(coalesce(p.role, ''))) in ('admin', 'super_admin')
  );
$$;

comment on function public.is_dashboard_admin() is
  'True when the signed-in user has profiles.role admin or super_admin.';

revoke all on function public.is_dashboard_admin() from public;
grant execute on function public.is_dashboard_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Sync profiles.last_seen from presence tables
-- ---------------------------------------------------------------------------

create or replace function public.touch_profile_last_seen(p_user_id uuid, p_seen timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_seen is null then
    return;
  end if;

  update public.profiles
  set
    last_seen = greatest(coalesce(last_seen, p_seen), p_seen),
    updated_at = now()
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

-- One-time backfill from existing presence rows
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

-- ---------------------------------------------------------------------------
-- 4. Internal stats view (Postgres / SQL Editor only — not granted to app roles)
-- ---------------------------------------------------------------------------

create or replace view public.developer_dashboard_stats_v as
with revenue as (
  select
    coalesce(sum(deposit_amount) filter (
      where status = 'paid'
        and deposit_amount is not null
        and created_at >= date_trunc('month', timezone('utc', now()))
    ), 0)::numeric(14, 2) as revenue_this_month,
    coalesce(sum(deposit_amount) filter (
      where status = 'paid' and deposit_amount is not null
    ), 0)::numeric(14, 2) as lifetime_revenue
  from public.contact_unlocks
),
users as (
  select
    count(*)::bigint as total_users,
    count(*) filter (
      where public.profile_role_normalized(profiles.*) = 'artist'
    )::bigint as total_artists,
    count(*) filter (
      where public.profile_role_normalized(profiles.*) = 'customer'
    )::bigint as total_customers,
    count(*) filter (
      where created_at >= timezone('utc', now()) - interval '7 days'
    )::bigint as new_users_this_week,
    count(*) filter (
      where last_seen >= timezone('utc', now()) - interval '24 hours'
    )::bigint as active_users_today_count
  from public.profiles
)
select
  u.total_users,
  u.total_artists,
  u.total_customers,
  u.new_users_this_week,
  u.active_users_today_count,
  (select count(*)::bigint from public.tattoo_requests) as total_tattoo_requests,
  r.revenue_this_month,
  r.lifetime_revenue,
  timezone('utc', now()) as generated_at
from users u
cross join revenue r;

comment on view public.developer_dashboard_stats_v is
  'Aggregate dashboard metrics. Use get_developer_dashboard() from the app (admin-only RPC).';

revoke all on public.developer_dashboard_stats_v from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC: single payload for Developer Dashboard (admin / super_admin only)
-- ---------------------------------------------------------------------------

create or replace function public.get_developer_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_stats record;
  v_active jsonb;
begin
  if not public.is_dashboard_admin() then
    raise exception 'Forbidden: developer dashboard requires admin or super_admin role'
      using errcode = '42501';
  end if;

  select * into v_stats from public.developer_dashboard_stats_v;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'display_name', p.display_name,
        'role', public.profile_role_normalized(p),
        'avatar_url', p.avatar_url,
        'last_seen', p.last_seen
      )
      order by p.last_seen desc nulls last
    ),
    '[]'::jsonb
  )
  into v_active
  from public.profiles p
  where p.last_seen >= timezone('utc', now()) - interval '24 hours';

  return jsonb_build_object(
    'total_users', v_stats.total_users,
    'total_artists', v_stats.total_artists,
    'total_customers', v_stats.total_customers,
    'new_users_this_week', v_stats.new_users_this_week,
    'active_users_today_count', v_stats.active_users_today_count,
    'active_users_today', v_active,
    'total_tattoo_requests', v_stats.total_tattoo_requests,
    'revenue_this_month', v_stats.revenue_this_month,
    'lifetime_revenue', v_stats.lifetime_revenue,
    'generated_at', v_stats.generated_at
  );
end;
$$;

comment on function public.get_developer_dashboard() is
  'All developer dashboard cards + active_users_today array. Admin/super_admin only.';

revoke all on function public.get_developer_dashboard() from public;
grant execute on function public.get_developer_dashboard() to authenticated;

-- Optional: active users only (same access rules)
create or replace function public.get_active_users_today()
returns table (
  id uuid,
  display_name text,
  role text,
  avatar_url text,
  last_seen timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_dashboard_admin() then
    raise exception 'Forbidden: developer dashboard requires admin or super_admin role'
      using errcode = '42501';
  end if;

  return query
  select
    p.id,
    p.display_name,
    public.profile_role_normalized(p),
    p.avatar_url,
    p.last_seen
  from public.profiles p
  where p.last_seen >= timezone('utc', now()) - interval '24 hours'
  order by p.last_seen desc nulls last;
end;
$$;

revoke all on function public.get_active_users_today() from public;
grant execute on function public.get_active_users_today() to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RLS: block direct table access to dashboard aggregates (RPC-only path)
--     Existing profiles RLS unchanged for normal app users.
--     No extra SELECT policies for admins on contact_unlocks — stats via RPC only.
-- ---------------------------------------------------------------------------

-- Grant service_role can read view in Supabase dashboard; app uses RPC only.

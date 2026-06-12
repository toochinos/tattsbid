-- Run once in Supabase Dashboard → SQL Editor.
-- Fixes online users counter: server UTC last_seen, count RPCs, cleanup bad rows.

create or replace function public.set_online_users_last_seen()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.last_seen := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists online_users_set_last_seen on public.online_users;
create trigger online_users_set_last_seen
  before insert or update on public.online_users
  for each row
  execute function public.set_online_users_last_seen();

create or replace function public.touch_online_presence(
  p_username text default '',
  p_user_type text default ''
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_seen timestamptz := timezone('utc', now());
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.online_users (user_id, username, user_type, last_seen)
  values (
    v_user_id,
    coalesce(p_username, ''),
    coalesce(p_user_type, ''),
    v_seen
  )
  on conflict (user_id) do update set
    username = excluded.username,
    user_type = excluded.user_type,
    last_seen = v_seen;

  return v_seen;
end;
$$;

grant execute on function public.touch_online_presence(text, text) to authenticated;

create or replace function public.prune_stale_online_users()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.online_users
  where last_seen <= timezone('utc', now()) - interval '60 seconds'
     or last_seen > timezone('utc', now()) + interval '1 minute';
end;
$$;

grant execute on function public.prune_stale_online_users() to authenticated;

create or replace function public.count_online_users()
returns bigint
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_count bigint;
  v_now timestamptz := timezone('utc', now());
begin
  perform public.prune_stale_online_users();
  select count(distinct user_id)::bigint into v_count
  from public.online_users
  where last_seen > v_now - interval '60 seconds'
    and last_seen <= v_now + interval '1 minute';
  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.count_online_users() to authenticated;

create or replace function public.get_online_users_count()
returns bigint
language plpgsql
volatile
security definer
set search_path = public
as $$
begin
  return public.count_online_users();
end;
$$;

grant execute on function public.get_online_users_count() to authenticated;

create or replace function public.count_active_users_today()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct user_id)::bigint
  from public.online_users
  where last_seen > timezone('utc', now()) - interval '24 hours'
    and last_seen <= timezone('utc', now()) + interval '1 minute';
$$;

grant execute on function public.count_active_users_today() to authenticated;

delete from public.online_users
where last_seen > timezone('utc', now()) + interval '1 minute';

-- Verify:
-- select public.count_online_users();
-- select user_id, last_seen, timezone('utc', now()) as server_now from online_users;

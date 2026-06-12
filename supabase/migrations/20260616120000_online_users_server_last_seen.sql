-- online_users.last_seen must always be server UTC (never client clock).

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

-- RPC: heartbeat upsert with Postgres now() (preferred from Flutter).
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

comment on function public.touch_online_presence(text, text) is
  'Upserts online_users for auth.uid(); last_seen = timezone(utc, now()).';

grant execute on function public.touch_online_presence(text, text) to authenticated;

-- One-time cleanup: rows with last_seen more than 1 minute in the future.
delete from public.online_users
where last_seen > timezone('utc', now()) + interval '1 minute';

-- Verify:
--   select trigger_name from information_schema.triggers
--   where event_object_table = 'online_users';
--   select public.touch_online_presence('', '');

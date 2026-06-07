-- online_users.last_seen is always set by PostgreSQL (never from the client).

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

comment on function public.set_online_users_last_seen() is
  'Sets online_users.last_seen to server UTC time on every insert/upsert.';

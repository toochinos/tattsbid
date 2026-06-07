-- Add profile fields to online_users for presence lists / admin views.
alter table public.online_users
  add column if not exists username text,
  add column if not exists user_type text;

comment on column public.online_users.username is
  'Copy of profiles.display_name at last heartbeat.';
comment on column public.online_users.user_type is
  'Copy of profiles.user_type (customer | tattoo_artist) at last heartbeat.';

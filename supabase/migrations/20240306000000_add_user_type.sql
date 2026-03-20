-- Add user_type column: 'tattoo_artist' or 'customer'.
alter table public.profiles add column if not exists user_type text;

-- Case-insensitive unique display names for non-empty values.
-- New signups no longer copy OAuth full_name into profiles.display_name so duplicate
-- names cannot block auth signup once this index exists. Users choose a unique name in the app.
--
-- If this migration fails on the unique index, dedupe existing rows first, e.g.:
--   select lower(trim(display_name)), count(*) from public.profiles
--   where display_name is not null and trim(display_name) <> ''
--   group by 1 having count(*) > 1;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    null,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create unique index if not exists profiles_display_name_lower_unique
  on public.profiles (lower(trim(display_name)))
  where display_name is not null and trim(display_name) <> '';

-- Optional UI role for Request Detail and future flows. Values: 'artist' | 'customer'.
-- When null, the app may fall back to user_type (tattoo_artist / customer).
alter table public.profiles add column if not exists role text;

comment on column public.profiles.role is
  'Optional. artist | customer. Used by client UI; bidding still enforced via user_type until migrated.';

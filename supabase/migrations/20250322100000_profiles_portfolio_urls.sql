-- Public portfolio image URLs for tattoo artists (max 10 enforced in app).
alter table public.profiles
  add column if not exists portfolio_urls jsonb not null default '[]'::jsonb;

comment on column public.profiles.portfolio_urls is
  'Array of public image URLs for artist portfolio (max 10 in app).';

-- Add description detail fields: placement, size, colour preference, artist creative freedom, timeframe.
alter table public.tattoo_requests add column if not exists placement text;
alter table public.tattoo_requests add column if not exists size text;
alter table public.tattoo_requests add column if not exists colour_preference text;
alter table public.tattoo_requests add column if not exists artist_creative_freedom boolean default true;
alter table public.tattoo_requests add column if not exists timeframe text;

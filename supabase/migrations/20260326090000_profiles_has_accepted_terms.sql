-- One-time TattsBid user agreement acceptance flag.
alter table public.profiles
add column if not exists has_accepted_terms boolean not null default false;

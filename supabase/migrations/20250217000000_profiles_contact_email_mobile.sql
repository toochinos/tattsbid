-- Public contact fields (used after winning bid / chat).
alter table public.profiles
  add column if not exists contact_email text,
  add column if not exists mobile text;

comment on column public.profiles.contact_email is 'Contact email shown to customers (can differ from auth email).';
comment on column public.profiles.mobile is 'Contact phone / mobile number.';

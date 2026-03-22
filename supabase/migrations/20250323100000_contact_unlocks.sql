-- Records successful Stripe deposit payments so customers can view artist contact on a request.
create table if not exists public.contact_unlocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  artist_id uuid not null references auth.users (id) on delete cascade,
  request_id uuid not null references public.tattoo_requests (id) on delete cascade,
  status text not null default 'paid' check (status in ('paid', 'pending')),
  created_at timestamptz not null default now(),
  constraint contact_unlocks_user_request_artist_unique unique (user_id, request_id, artist_id)
);

create index if not exists contact_unlocks_user_request_idx
  on public.contact_unlocks (user_id, request_id);

alter table public.contact_unlocks enable row level security;

-- Customers can only read their own unlock rows (authoritative for UI).
create policy contact_unlocks_select_own on public.contact_unlocks
  for select
  using (auth.uid() = user_id);

-- Inserts only via [record_contact_unlock] (security definer).

comment on table public.contact_unlocks is
  'Stripe deposit unlock: customer (user_id) may view artist contact for request_id after status=paid.';

create or replace function public.record_contact_unlock (p_request_id uuid, p_artist_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_win uuid;
  v_bidder uuid;
begin
  select user_id, winning_bid_id
  into v_owner, v_win
  from public.tattoo_requests
  where id = p_request_id;

  if v_owner is null then
    raise exception 'Request not found';
  end if;
  if v_owner <> auth.uid() then
    raise exception 'Not the request owner';
  end if;
  if v_win is null then
    raise exception 'No winning bid on this request';
  end if;

  select bidder_id into v_bidder
  from public.bids
  where id = v_win;

  if v_bidder is null or v_bidder <> p_artist_id then
    raise exception 'Artist does not match winning bid';
  end if;

  insert into public.contact_unlocks (user_id, artist_id, request_id, status)
  values (auth.uid(), p_artist_id, p_request_id, 'paid')
  on conflict on constraint contact_unlocks_user_request_artist_unique
  do update set status = excluded.status;
end;
$$;

grant execute on function public.record_contact_unlock (uuid, uuid) to authenticated;

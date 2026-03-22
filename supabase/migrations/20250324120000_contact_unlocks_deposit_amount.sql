-- Store 10% deposit paid (dollars) for audit and UI.
alter table public.contact_unlocks
  add column if not exists deposit_amount numeric;

comment on column public.contact_unlocks.deposit_amount is
  'Stripe deposit in dollars (e.g. 10% of winning bid).';

-- Replace function to accept optional deposit amount (from client after payment).
drop function if exists public.record_contact_unlock(uuid, uuid);

create or replace function public.record_contact_unlock (
  p_request_id uuid,
  p_artist_id uuid,
  p_deposit_amount numeric default null
)
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

  insert into public.contact_unlocks (
    user_id,
    artist_id,
    request_id,
    status,
    deposit_amount
  )
  values (
    auth.uid(),
    p_artist_id,
    p_request_id,
    'paid',
    p_deposit_amount
  )
  on conflict on constraint contact_unlocks_user_request_artist_unique
  do update set
    status = excluded.status,
    deposit_amount = coalesce(excluded.deposit_amount, public.contact_unlocks.deposit_amount);
end;
$$;

grant execute on function public.record_contact_unlock (uuid, uuid, numeric) to authenticated;

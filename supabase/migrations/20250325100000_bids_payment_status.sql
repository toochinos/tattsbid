-- Payment state for deposit flow (set by Node `/success` or Stripe webhook path).
alter table public.bids
  add column if not exists payment_status text not null default 'unpaid';

comment on column public.bids.payment_status is
  'unpaid | paid — customer deposit for this bid (updated server-side).';

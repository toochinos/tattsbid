-- Add a winning bid reference so customers can pick a winner.
ALTER TABLE public.tattoo_requests
ADD COLUMN IF NOT EXISTS winning_bid_id uuid REFERENCES public.bids(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tattoo_requests_winning_bid_id
ON public.tattoo_requests(winning_bid_id);


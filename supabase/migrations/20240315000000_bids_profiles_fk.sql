-- Add FK from bids.bidder_id to profiles so we can embed profiles(display_name) in selects.
ALTER TABLE public.bids DROP CONSTRAINT IF EXISTS bids_bidder_id_fkey;
ALTER TABLE public.bids ADD CONSTRAINT bids_bidder_id_fkey
  FOREIGN KEY (bidder_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

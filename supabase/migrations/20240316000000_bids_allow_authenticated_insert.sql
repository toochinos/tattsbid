-- Fix RLS: allow any authenticated user to place bids on open requests.
-- The app shows the Bid button only to tattoo artists, but RLS was blocking
-- when profile user_type was 'customer' or missing.
DROP POLICY IF EXISTS "Tattoo artists can place bids" ON public.bids;
DROP POLICY IF EXISTS "Authenticated users can place bids" ON public.bids;

CREATE POLICY "Authenticated users can place bids"
  ON public.bids FOR INSERT
  TO authenticated
  WITH CHECK (
    bidder_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.tattoo_requests tr
      WHERE tr.id = request_id AND tr.status = 'open'
    )
  );

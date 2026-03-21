-- Restore: only profiles with user_type = 'tattoo_artist' can insert bids.
-- (20240318000000 had temporarily allowed any authenticated user.)

DROP POLICY IF EXISTS "Authenticated users can place bids" ON public.bids;
DROP POLICY IF EXISTS "Tattoo artists can place bids" ON public.bids;

CREATE POLICY "Tattoo artists can place bids"
  ON public.bids FOR INSERT
  TO authenticated
  WITH CHECK (
    bidder_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.user_type = 'tattoo_artist'
    )
    AND EXISTS (
      SELECT 1 FROM public.tattoo_requests tr
      WHERE tr.id = request_id AND tr.status = 'open'
    )
  );

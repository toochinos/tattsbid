-- Fix 42501 (insufficient privilege / RLS violation) when inserting bids.
-- Run in Supabase SQL Editor if you get code 42501 on bid insert.

-- Ensure authenticated role can insert.
GRANT INSERT ON public.bids TO authenticated;
GRANT SELECT ON public.bids TO authenticated;

-- Replace INSERT policy with permissive one (any authenticated user).
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

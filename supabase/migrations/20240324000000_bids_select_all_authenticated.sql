-- Allow all authenticated users to see all bids (e.g. for transparency / discovery).
-- Run this entire block in Supabase Dashboard → SQL Editor. Safe to run multiple times.
GRANT SELECT ON public.bids TO authenticated;
DROP POLICY IF EXISTS "Users can view bids on visible requests" ON public.bids;
DROP POLICY IF EXISTS "Authenticated users can view all bids" ON public.bids;
CREATE POLICY "Authenticated users can view all bids"
  ON public.bids FOR SELECT
  TO authenticated
  USING (true);

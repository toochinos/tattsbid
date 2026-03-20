-- Fix: ensure bids table has bidder_id column (schema cache error PGRST204).
-- Run this if you get "Could not find the 'bidder_id' column of 'bids'".
-- If bids exists with wrong structure, we drop and recreate (existing bids will be lost).
DROP TABLE IF EXISTS public.bids CASCADE;

CREATE TABLE public.bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.tattoo_requests(id) ON DELETE CASCADE,
  bidder_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (request_id, bidder_id)
);

CREATE INDEX IF NOT EXISTS idx_bids_request_id ON public.bids(request_id);
CREATE INDEX IF NOT EXISTS idx_bids_created_at ON public.bids(created_at DESC);

ALTER TABLE public.bids ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view bids on visible requests" ON public.bids;
CREATE POLICY "Users can view bids on visible requests"
  ON public.bids FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tattoo_requests tr
      WHERE tr.id = request_id
        AND (tr.status = 'open' OR tr.user_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Tattoo artists can place bids" ON public.bids;
DROP POLICY IF EXISTS "Authenticated users can place bids" ON public.bids;
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

DROP POLICY IF EXISTS "Users can update own bids" ON public.bids;
CREATE POLICY "Users can update own bids"
  ON public.bids FOR UPDATE
  USING (bidder_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own bids" ON public.bids;
CREATE POLICY "Users can delete own bids"
  ON public.bids FOR DELETE
  USING (bidder_id = auth.uid());

-- Enable realtime for live bid updates.
ALTER PUBLICATION supabase_realtime ADD TABLE public.bids;

-- Allow authenticated users to see tattoo requests that are still listed for discovery
-- (open, in progress, or completed) so Explore can show e.g. "Bid closed" after payment.
-- Owners already see their rows via "Users can view own tattoo requests".

create policy "Authenticated users can view discoverable tattoo requests"
  on public.tattoo_requests for select
  to authenticated
  using (status in ('open', 'in_progress', 'completed'));

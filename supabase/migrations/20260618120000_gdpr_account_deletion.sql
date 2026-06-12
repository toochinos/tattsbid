-- GDPR account deletion: ensure reviews FK cascades and document rollback.
-- Does not change existing tables beyond adding missing FK constraints on reviews.
-- Auth user deletion (via delete-user edge function) cascades to all user-owned rows.

-- ---------------------------------------------------------------------------
-- Forward: reviews FK constraints (if public.reviews exists)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.reviews') IS NULL THEN
    RAISE NOTICE 'public.reviews not found — skip GDPR reviews FK migration';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reviews_user_id_fkey'
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reviews_artist_id_fkey'
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_artist_id_fkey
      FOREIGN KEY (artist_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

COMMENT ON TABLE public.reviews IS
  'Artist reviews. user_id and artist_id cascade when auth user or profile is deleted.';

-- ---------------------------------------------------------------------------
-- Rollback (manual — run only if reverting this migration):
--
--   ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_user_id_fkey;
--   ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_artist_id_fkey;
--
-- Note: Other user-owned tables already CASCADE from auth.users via existing
-- migrations (profiles, tattoo_requests, bids, chat_messages, contact_unlocks,
-- online_users, live_online, live_messages, tattsagram_post, tattsagram_likes).
-- ---------------------------------------------------------------------------

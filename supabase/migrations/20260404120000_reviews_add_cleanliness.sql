-- Dual ratings: overall experience (`rating`) + studio cleanliness (`cleanliness`), both 1–5.
-- Skips if `public.reviews` does not exist yet.

DO $$
BEGIN
  IF to_regclass('public.reviews') IS NULL THEN
    RAISE NOTICE 'public.reviews not found — skip reviews_add_cleanliness';
    RETURN;
  END IF;

  ALTER TABLE public.reviews
    ADD COLUMN IF NOT EXISTS cleanliness smallint;

  UPDATE public.reviews
  SET cleanliness = rating
  WHERE cleanliness IS NULL;

  ALTER TABLE public.reviews
    ALTER COLUMN cleanliness SET NOT NULL;

  ALTER TABLE public.reviews
    DROP CONSTRAINT IF EXISTS reviews_cleanliness_range;

  ALTER TABLE public.reviews
    ADD CONSTRAINT reviews_cleanliness_range
    CHECK (cleanliness >= 1 AND cleanliness <= 5);
END $$;

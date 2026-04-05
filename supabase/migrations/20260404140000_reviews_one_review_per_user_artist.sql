-- At most one review per (user_id, artist_id).
DO $$
BEGIN
  IF to_regclass('public.reviews') IS NULL THEN
    RAISE NOTICE 'public.reviews not found — skip reviews_one_review_per_user_artist';
    RETURN;
  END IF;

  DELETE FROM public.reviews
  WHERE id IN (
    SELECT id
    FROM (
      SELECT id,
             ROW_NUMBER() OVER (
               PARTITION BY user_id, artist_id
               ORDER BY created_at DESC NULLS LAST, id DESC
             ) AS rn
      FROM public.reviews
    ) t
    WHERE t.rn > 1
  );

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reviews_user_id_artist_id_key'
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_user_id_artist_id_key UNIQUE (user_id, artist_id);
  END IF;
END $$;

-- Delete Jesus (jesus@gmail.com) — orphan profile cleanup.
-- Project: ikkfdwjmqujgkokpqhez → SQL Editor.
-- Auth may already be gone; Artists tab reads public.profiles.

-- STEP 1 — FIND (run first):
SELECT id, display_name, location, user_type, contact_email
FROM public.profiles
WHERE lower(coalesce(contact_email, '')) = 'jesus@gmail.com'
   OR display_name ILIKE 'Jesus'
   OR display_name ILIKE '%Jesus%';

-- STEP 2 — DELETE all matches (run second; safe if table missing):
DO $$
DECLARE
  r record;
  n int := 0;
BEGIN
  FOR r IN
    SELECT id, display_name FROM public.profiles
    WHERE lower(coalesce(contact_email, '')) = 'jesus@gmail.com'
       OR display_name ILIKE 'Jesus'
       OR (display_name ILIKE '%Jesus%' AND display_name NOT ILIKE '%Jesus%Christ%')
  LOOP
    RAISE NOTICE 'Deleting % (%)', r.display_name, r.id;

    IF to_regclass('public.reviews') IS NOT NULL THEN
      DELETE FROM public.reviews WHERE user_id = r.id OR artist_id = r.id;
    END IF;

    IF to_regclass('public.tattsagram_likes') IS NOT NULL THEN
      DELETE FROM public.tattsagram_likes WHERE user_id = r.id;
    END IF;

    IF to_regclass('public.tattsagram_post') IS NOT NULL THEN
      DELETE FROM public.tattsagram_post WHERE user_id = r.id;
    END IF;

    IF to_regclass('public.live_messages') IS NOT NULL THEN
      DELETE FROM public.live_messages WHERE user_id = r.id;
    END IF;

    IF to_regclass('public.live_online') IS NOT NULL THEN
      DELETE FROM public.live_online WHERE user_id = r.id;
    END IF;

    IF to_regclass('public.online_users') IS NOT NULL THEN
      DELETE FROM public.online_users WHERE user_id = r.id;
    END IF;

    IF to_regclass('public.chat_messages') IS NOT NULL THEN
      DELETE FROM public.chat_messages
      WHERE sender_id = r.id OR receiver_id = r.id;
    END IF;

    IF to_regclass('public.contact_unlocks') IS NOT NULL THEN
      DELETE FROM public.contact_unlocks
      WHERE user_id = r.id OR artist_id = r.id;
    END IF;

    IF to_regclass('public.bids') IS NOT NULL THEN
      DELETE FROM public.bids WHERE bidder_id = r.id;
    END IF;

    IF to_regclass('public.tattoo_requests') IS NOT NULL THEN
      DELETE FROM public.tattoo_requests WHERE user_id = r.id;
    END IF;

    DELETE FROM public.profiles WHERE id = r.id;
    DELETE FROM auth.users WHERE id = r.id;

    n := n + 1;
  END LOOP;

  IF n = 0 THEN
    RAISE EXCEPTION 'No profile found for jesus@gmail.com / Jesus. Run STEP 1.';
  END IF;

  RAISE NOTICE 'Deleted % profile(s). Force-quit TattsBid and reopen.', n;
END $$;

-- STEP 3 — VERIFY (0 rows):
SELECT id, display_name, contact_email FROM public.profiles
WHERE lower(coalesce(contact_email, '')) = 'jesus@gmail.com'
   OR display_name ILIKE 'Jesus';

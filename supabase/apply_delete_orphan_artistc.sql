-- Remove Artist-C from Artists directory (orphan profile — auth may already be deleted).
-- Project: ikkfdwjmqujgkokpqhez → SQL Editor.
--
-- STEP 1 — RUN THIS FIRST (see the UUID):
SELECT id, display_name, contact_email, location, city, user_type, avatar_url
FROM public.profiles
WHERE display_name ILIKE '%Artist-C%'
   OR display_name ILIKE '%Artist%C%'
   OR location ILIKE '%Macleod%'
   OR lower(coalesce(contact_email, '')) = 'artistc@gmail.com';

-- STEP 2 — RUN THIS TO DELETE (removes profile + listings + reviews + all linked rows):

DO $$
DECLARE
  r record;
  v_deleted int := 0;
BEGIN
  FOR r IN
    SELECT id, display_name
    FROM public.profiles
    WHERE display_name ILIKE 'Artist-C'
       OR display_name ILIKE '%Artist-C%'
       OR (display_name ILIKE '%Artist%' AND location ILIKE '%Macleod%')
       OR lower(coalesce(contact_email, '')) = 'artistc@gmail.com'
  LOOP
    RAISE NOTICE 'Deleting uid=% name=%', r.id, r.display_name;

    DELETE FROM public.reviews
    WHERE user_id = r.id OR artist_id = r.id;

    DELETE FROM public.tattsagram_likes WHERE user_id = r.id;
    DELETE FROM public.tattsagram_post WHERE user_id = r.id;
    DELETE FROM public.tattsagram_posts WHERE user_id = r.id;
    DELETE FROM public.live_messages WHERE user_id = r.id;
    DELETE FROM public.live_online WHERE user_id = r.id;
    DELETE FROM public.online_users WHERE user_id = r.id;
    DELETE FROM public.chat_messages
    WHERE sender_id = r.id OR receiver_id = r.id;
    DELETE FROM public.contact_unlocks
    WHERE user_id = r.id OR artist_id = r.id;
    DELETE FROM public.bids WHERE bidder_id = r.id;
    DELETE FROM public.tattoo_requests WHERE user_id = r.id;
    DELETE FROM public.profiles WHERE id = r.id;
    DELETE FROM auth.users WHERE id = r.id;

    v_deleted := v_deleted + 1;
  END LOOP;

  IF v_deleted = 0 THEN
    RAISE EXCEPTION
      'No profile matched Artist-C / Macleod / artistc@gmail.com. Run STEP 1 and share the id.';
  END IF;

  RAISE NOTICE 'Deleted % artist profile(s).', v_deleted;
END $$;

-- STEP 3 — VERIFY (must return 0 rows):
SELECT id, display_name, location FROM public.profiles
WHERE display_name ILIKE '%Artist-C%' OR location ILIKE '%Macleod%';

-- STEP 4 — App: force-quit TattsBid and reopen (or pull down to refresh Artists tab).

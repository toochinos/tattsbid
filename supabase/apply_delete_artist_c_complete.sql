-- =============================================================================
-- ARTIST-C — FIND + DELETE (run on project ikkfdwjmqujgkokpqhez ONLY)
-- Dashboard URL must contain: ikkfdwjmqujgkokpqhez
-- =============================================================================

-- 1) LIST every tattoo artist (Artist-C must appear here if on THIS project)
SELECT id, display_name, user_type, location, contact_email, avatar_url
FROM public.profiles
WHERE lower(trim(coalesce(user_type, ''))) IN ('tattoo_artist', 'tattoo artist', 'artist')
   OR display_name ILIKE '%Artist%'
ORDER BY display_name;

-- 2) DELETE by UUID — replace PASTE_UUID below with id from step 1, then RUN ONLY this block:

/*
DO $$
DECLARE
  v_id uuid := 'PASTE_UUID_HERE';
BEGIN
  DELETE FROM public.reviews WHERE user_id = v_id OR artist_id = v_id;
  DELETE FROM public.tattsagram_likes WHERE user_id = v_id;
  DELETE FROM public.tattsagram_post WHERE user_id = v_id;
  DELETE FROM public.tattsagram_posts WHERE user_id = v_id;
  DELETE FROM public.live_messages WHERE user_id = v_id;
  DELETE FROM public.live_online WHERE user_id = v_id;
  DELETE FROM public.online_users WHERE user_id = v_id;
  DELETE FROM public.chat_messages WHERE sender_id = v_id OR receiver_id = v_id;
  DELETE FROM public.contact_unlocks WHERE user_id = v_id OR artist_id = v_id;
  DELETE FROM public.bids WHERE bidder_id = v_id;
  DELETE FROM public.tattoo_requests WHERE user_id = v_id;
  DELETE FROM public.profiles WHERE id = v_id;
  DELETE FROM auth.users WHERE id = v_id;
  RAISE NOTICE 'Deleted uid %', v_id;
END $$;
*/

-- 3) OR auto-delete all Artist-C / Macleod matches (run if step 1 shows Artist-C):

DO $$
DECLARE
  r record;
  n int := 0;
BEGIN
  FOR r IN
    SELECT id, display_name FROM public.profiles
    WHERE display_name ILIKE '%Artist-C%'
       OR display_name ILIKE '%Artist%C%'
       OR (display_name ILIKE '%Artist%' AND coalesce(location, '') ILIKE '%Macleod%')
       OR lower(trim(coalesce(contact_email, ''))) = 'artistc@gmail.com'
  LOOP
    RAISE NOTICE 'Deleting % (%)', r.display_name, r.id;
    DELETE FROM public.reviews WHERE user_id = r.id OR artist_id = r.id;
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
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'Deleted % profile(s). Wrong project if n=0 but app still shows Artist-C.', n;
END $$;

-- 4) VERIFY (0 rows):
SELECT id, display_name FROM public.profiles
WHERE display_name ILIKE '%Artist%C%' OR location ILIKE '%Macleod%';

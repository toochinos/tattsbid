-- Delete Artist-C only (uid from SQL search 2026-06-12).
-- Project: ikkfdwjmqujgkokpqhez
-- Note: table is tattsagram_post (singular), NOT tattsagram_posts.

DO $$
DECLARE
  v_id uuid := '666d029c-1db0-48a7-8d74-d151981257c3';
BEGIN
  IF to_regclass('public.reviews') IS NOT NULL THEN
    DELETE FROM public.reviews WHERE user_id = v_id OR artist_id = v_id;
  END IF;

  IF to_regclass('public.tattsagram_likes') IS NOT NULL THEN
    DELETE FROM public.tattsagram_likes WHERE user_id = v_id;
  END IF;

  IF to_regclass('public.tattsagram_post') IS NOT NULL THEN
    DELETE FROM public.tattsagram_post WHERE user_id = v_id;
  END IF;

  IF to_regclass('public.live_messages') IS NOT NULL THEN
    DELETE FROM public.live_messages WHERE user_id = v_id;
  END IF;

  IF to_regclass('public.live_online') IS NOT NULL THEN
    DELETE FROM public.live_online WHERE user_id = v_id;
  END IF;

  IF to_regclass('public.online_users') IS NOT NULL THEN
    DELETE FROM public.online_users WHERE user_id = v_id;
  END IF;

  IF to_regclass('public.chat_messages') IS NOT NULL THEN
    DELETE FROM public.chat_messages
    WHERE sender_id = v_id OR receiver_id = v_id;
  END IF;

  IF to_regclass('public.contact_unlocks') IS NOT NULL THEN
    DELETE FROM public.contact_unlocks
    WHERE user_id = v_id OR artist_id = v_id;
  END IF;

  IF to_regclass('public.bids') IS NOT NULL THEN
    DELETE FROM public.bids WHERE bidder_id = v_id;
  END IF;

  IF to_regclass('public.tattoo_requests') IS NOT NULL THEN
    DELETE FROM public.tattoo_requests WHERE user_id = v_id;
  END IF;

  DELETE FROM public.profiles WHERE id = v_id;
  DELETE FROM auth.users WHERE id = v_id;

  RAISE NOTICE 'Artist-C deleted (uid %)', v_id;
END $$;

-- Verify (0 rows):
-- SELECT * FROM public.profiles WHERE id = '666d029c-1db0-48a7-8d74-d151981257c3';

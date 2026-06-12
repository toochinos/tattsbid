-- One-shot manual GDPR deletion for a stuck auth user.
-- Run in Supabase Dashboard → SQL Editor (project: ikkfdwjmqujgkokpqhez).
--
-- Tooch account from dashboard screenshot:
--   UID:   916c300f-648a-476e-a81f-24e3c01cd04b
--   Email: toochinos@gmail.com
--
-- After running, verify:
--   SELECT id, email FROM auth.users WHERE id = '916c300f-648a-476e-a81f-24e3c01cd04b';
--   SELECT * FROM public.profiles WHERE id = '916c300f-648a-476e-a81f-24e3c01cd04b';

DO $$
DECLARE
  v_user_id uuid := '916c300f-648a-476e-a81f-24e3c01cd04b';
BEGIN
  RAISE NOTICE 'Purging public data for user %', v_user_id;

  IF to_regclass('public.reviews') IS NOT NULL THEN
    DELETE FROM public.reviews
    WHERE user_id = v_user_id OR artist_id = v_user_id;
  END IF;

  IF to_regclass('public.tattsagram_likes') IS NOT NULL THEN
    DELETE FROM public.tattsagram_likes WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.tattsagram_post') IS NOT NULL THEN
    DELETE FROM public.tattsagram_post WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.tattsagram_posts') IS NOT NULL THEN
    DELETE FROM public.tattsagram_posts WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.live_messages') IS NOT NULL THEN
    DELETE FROM public.live_messages WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.live_online') IS NOT NULL THEN
    DELETE FROM public.live_online WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.online_users') IS NOT NULL THEN
    DELETE FROM public.online_users WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.chat_messages') IS NOT NULL THEN
    DELETE FROM public.chat_messages
    WHERE sender_id = v_user_id OR receiver_id = v_user_id;
  END IF;

  IF to_regclass('public.contact_unlocks') IS NOT NULL THEN
    DELETE FROM public.contact_unlocks
    WHERE user_id = v_user_id OR artist_id = v_user_id;
  END IF;

  IF to_regclass('public.bids') IS NOT NULL THEN
    DELETE FROM public.bids WHERE bidder_id = v_user_id;
  END IF;

  IF to_regclass('public.tattoo_requests') IS NOT NULL THEN
    DELETE FROM public.tattoo_requests WHERE user_id = v_user_id;
  END IF;

  IF to_regclass('public.profiles') IS NOT NULL THEN
    DELETE FROM public.profiles WHERE id = v_user_id;
  END IF;

  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'Done. Auth user % should be removed.', v_user_id;
END $$;

-- Verify removal:
-- SELECT id, email FROM auth.users WHERE email = 'toochinos@gmail.com';
-- SELECT count(*) FROM public.profiles WHERE id = '916c300f-648a-476e-a81f-24e3c01cd04b';

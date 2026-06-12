-- One-shot GDPR deletion for Artist-C (artistc@gmail.com).
-- Run in Supabase Dashboard → SQL Editor (project: ikkfdwjmqujgkokpqhez).

DO $$
DECLARE
  v_email text := 'artistc@gmail.com';
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE lower(email) = lower(v_email);

  IF v_user_id IS NULL THEN
    SELECT id INTO v_user_id FROM public.profiles
    WHERE lower(coalesce(contact_email, '')) = lower(v_email)
       OR display_name ILIKE 'Artist-C'
       OR display_name ILIKE '%Artist-C%'
    LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'No user or profile found for %. If auth was already deleted, run apply_delete_orphan_artistc.sql instead.',
      v_email;
  END IF;

  RAISE NOTICE 'Purging all data for % (uid: %)', v_email, v_user_id;

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

  RAISE NOTICE 'Done. Deleted auth user % (%)', v_email, v_user_id;
END $$;

-- Verify (should return 0 rows / 0 counts):
-- SELECT id, email FROM auth.users WHERE email = 'artistc@gmail.com';
-- SELECT * FROM public.profiles WHERE id IN (SELECT id FROM auth.users WHERE email = 'artistc@gmail.com');

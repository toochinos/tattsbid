-- Tattsagram weighted feed: like counts for popularity weighting (weight = likes_count + 1).

alter table public.tattsagram_post
  add column if not exists likes_count integer not null default 0;

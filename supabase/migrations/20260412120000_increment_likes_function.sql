-- Optional maintenance helper: bumps [tattsagram_post.likes_count] by one.
-- Normal likes flow: insert/delete [tattsagram_likes] only — triggers keep counts in sync.
-- Do not call this from the app together with a like insert (double-count).
-- Execute restricted to service_role to avoid inflating counts without a matching like row.

create or replace function public.increment_likes(p_post_id uuid)
returns void
language sql
security definer
set search_path = public
volatile
as $$
  update public.tattsagram_post
  set likes_count = likes_count + 1
  where id = p_post_id;
$$;

revoke all on function public.increment_likes(uuid) from public;
revoke all on function public.increment_likes(uuid) from anon, authenticated;
grant execute on function public.increment_likes(uuid) to service_role;

-- Tattsagram: one like per user per post; keeps tattsagram_post.likes_count in sync.

create table if not exists public.tattsagram_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  post_id uuid not null references public.tattsagram_post (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

create index if not exists idx_tattsagram_likes_post_id
  on public.tattsagram_likes (post_id);

create index if not exists idx_tattsagram_likes_user_id
  on public.tattsagram_likes (user_id);

alter table public.tattsagram_likes enable row level security;

drop policy if exists "Tattsagram likes select own" on public.tattsagram_likes;
create policy "Tattsagram likes select own"
  on public.tattsagram_likes
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Tattsagram likes insert own" on public.tattsagram_likes;
create policy "Tattsagram likes insert own"
  on public.tattsagram_likes
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Tattsagram likes delete own" on public.tattsagram_likes;
create policy "Tattsagram likes delete own"
  on public.tattsagram_likes
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.tattsagram_likes_sync_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.tattsagram_post
    set likes_count = likes_count + 1
    where id = new.post_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.tattsagram_post
    set likes_count = greatest(0, likes_count - 1)
    where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists tattsagram_likes_insert_count on public.tattsagram_likes;
create trigger tattsagram_likes_insert_count
  after insert on public.tattsagram_likes
  for each row execute function public.tattsagram_likes_sync_count();

drop trigger if exists tattsagram_likes_delete_count on public.tattsagram_likes;
create trigger tattsagram_likes_delete_count
  after delete on public.tattsagram_likes
  for each row execute function public.tattsagram_likes_sync_count();

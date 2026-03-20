-- Profiles table for user display name, avatar, and location.
-- Run this in Supabase SQL Editor if you use Supabase migrations.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  location text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- RLS: users can read and update their own profile.
alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

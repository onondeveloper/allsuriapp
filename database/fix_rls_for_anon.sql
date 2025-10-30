-- Fix RLS policies to allow anonymous users to read marketplace_listings
-- This allows the app to work even when Supabase Auth session is not properly set
-- Run this in Supabase SQL Editor

-- marketplace_listings: Allow anon users to read open/created/withdrawn listings
drop policy if exists sel_marketplace_listings on public.marketplace_listings;
create policy sel_marketplace_listings on public.marketplace_listings
for select
to authenticated, anon
using (
  status = 'open' or status = 'created' or status = 'withdrawn' or posted_by = auth.uid() or claimed_by = auth.uid()
);

-- community_posts already allows true, so no change needed
-- But let's make it explicit for anon users
drop policy if exists community_posts_select on public.community_posts;
create policy community_posts_select on public.community_posts 
for select 
to authenticated, anon
using (true);

-- community_comments: Allow anon users to read
drop policy if exists community_comments_select on public.community_comments;
create policy community_comments_select on public.community_comments 
for select 
to authenticated, anon
using (true);


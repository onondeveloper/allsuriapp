-- Community tables
-- Note: separate SQL for users.avatar_url and storage buckets will be created
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  authorid uuid not null references public.users(id) on delete cascade,
  title text not null,
  content text not null,
  tags text[] default '{}',
  upvotes int not null default 0,
  commentscount int not null default 0,
  createdat timestamptz not null default now(),
  updatedat timestamptz
);

create index if not exists idx_community_posts_createdat on public.community_posts(createdat desc);
create index if not exists idx_community_posts_author on public.community_posts(authorid);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  postid uuid not null references public.community_posts(id) on delete cascade,
  authorid uuid not null references public.users(id) on delete cascade,
  content text not null,
  createdat timestamptz not null default now()
);

create index if not exists idx_community_comments_post on public.community_comments(postid, createdat);

-- RPCs for counters
create or replace function public.increment_post_upvotes(post_id uuid)
returns void as $$
begin
  update public.community_posts set upvotes = coalesce(upvotes,0) + 1, updatedat = now() where id = post_id;
end;
$$ language plpgsql security definer;

create or replace function public.increment_post_comments(post_id uuid)
returns void as $$
begin
  update public.community_posts set commentscount = coalesce(commentscount,0) + 1, updatedat = now() where id = post_id;
end;
$$ language plpgsql security definer;

-- Enable RLS
alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;

-- Simple RLS: any authenticated user can read; only owners can write
drop policy if exists community_posts_select on public.community_posts;
drop policy if exists community_posts_insert on public.community_posts;
drop policy if exists community_posts_update on public.community_posts;

create policy community_posts_select on public.community_posts for select using (true);
create policy community_posts_insert on public.community_posts for insert with check (auth.uid() = authorid);
create policy community_posts_update on public.community_posts for update using (auth.uid() = authorid);

drop policy if exists community_comments_select on public.community_comments;
drop policy if exists community_comments_insert on public.community_comments;

create policy community_comments_select on public.community_comments for select using (true);
create policy community_comments_insert on public.community_comments for insert with check (auth.uid() = authorid);
-- updates/deletes are omitted for simplicity

-- Marketplace schema and claim RPC for Supabase
-- Run this in Supabase SQL editor

-- Extensions (gen_random_uuid)
create extension if not exists pgcrypto;

-- Table: marketplace_listings
create table if not exists public.marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  jobid uuid not null references public.jobs(id) on delete cascade,
  title text not null,
  description text,
  region text,
  category text,
  budget_amount numeric,
  posted_by uuid not null references public.users(id) on delete cascade,
  status text not null check (status in ('open','assigned','withdrawn','expired','cancelled', 'created')) default 'open',
  claimed_by uuid references public.users(id) on delete set null,
  claimed_at timestamptz,
  expires_at timestamptz,
  createdat timestamptz not null default now(),
  updatedat timestamptz not null default now()
);

-- Indexes for filtering
create index if not exists idx_marketplace_listings_status on public.marketplace_listings(status);
create index if not exists idx_marketplace_listings_region on public.marketplace_listings(region);
create index if not exists idx_marketplace_listings_category on public.marketplace_listings(category);
create index if not exists idx_marketplace_listings_createdat on public.marketplace_listings(createdat desc);

-- RLS policies
alter table public.marketplace_listings enable row level security;

-- Read: open listings are visible to any authenticated user (business),
-- plus your own posted/claimed listings
drop policy if exists sel_marketplace_listings on public.marketplace_listings;
create policy sel_marketplace_listings on public.marketplace_listings
for select
to authenticated
using (
  status = 'open' or status = 'created' or posted_by = auth.uid() or claimed_by = auth.uid()
);

-- Insert: only authenticated users can post their own listings
drop policy if exists ins_marketplace_listings on public.marketplace_listings;
create policy ins_marketplace_listings on public.marketplace_listings
for insert
to authenticated
with check (
  posted_by = auth.uid()
);

-- Update: poster can withdraw/update while open; admin can manage separately if needed
drop policy if exists upd_marketplace_listings on public.marketplace_listings;
create policy upd_marketplace_listings on public.marketplace_listings
for update
to authenticated
using (
  posted_by = auth.uid() and status = 'open'
)
with check (
  posted_by = auth.uid()
);

-- RPC: claim_listing(listing_id, business_id) => boolean
drop function if exists public.claim_listing(uuid, uuid);
create or replace function public.claim_listing(p_listing_id uuid, p_business_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_jobid uuid;
begin
  -- Disallow claiming own listing
  if exists (
    select 1 from public.marketplace_listings
    where id = p_listing_id and posted_by = p_business_id
  ) then
    return false;
  end if;

  -- Atomic state transition from open -> assigned
  update public.marketplace_listings
     set status     = 'assigned',
         claimed_by = p_business_id,
         claimed_at = v_now,
         updatedat  = v_now
   where id = p_listing_id
     and status = 'open'
     and claimed_by is null;

  if not found then
    return false; -- already taken or not open
  end if;

  -- Sync job assignment
  select jobid into v_jobid from public.marketplace_listings where id = p_listing_id;
  if v_jobid is not null then
    update public.jobs
       set assignedbusinessid = p_business_id,
           status = coalesce(status, 'in_progress')
     where id = v_jobid;
  end if;

  -- Optional: activity log (if table exists)
  -- insert into public.activity_logs(entity_type, entity_id, action, actor_userid, metadata)
  -- values('listing', p_listing_id, 'claimed', p_business_id, '{}');

  return true;
end;
$$;

revoke all on function public.claim_listing(uuid, uuid) from public;
grant execute on function public.claim_listing(uuid, uuid) to authenticated;



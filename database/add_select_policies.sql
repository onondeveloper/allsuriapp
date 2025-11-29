-- ==========================================
-- 🔧 SELECT RLS 정책 추가 (조회 권한 문제 해결)
-- ==========================================

-- 1. marketplace_listings SELECT 정책 (모든 사용자 조회 가능)
DROP POLICY IF EXISTS select_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.marketplace_listings;

CREATE POLICY select_marketplace_listings ON public.marketplace_listings
FOR SELECT
TO authenticated, anon
USING (true);

-- 2. order_bids SELECT 정책 (자신의 입찰 또는 오더 소유자 조회 가능)
DROP POLICY IF EXISTS select_order_bids ON public.order_bids;
DROP POLICY IF EXISTS "Enable read access for own bids or order owners" ON public.order_bids;

CREATE POLICY select_order_bids ON public.order_bids
FOR SELECT
TO authenticated, anon
USING (
  bidder_id::text = (auth.uid())::text 
  OR EXISTS (
    SELECT 1 FROM marketplace_listings
    WHERE id = order_bids.listing_id
    AND posted_by::text = (auth.uid())::text
  )
);

-- 3. jobs SELECT 정책 (관련 당사자 조회 가능)
DROP POLICY IF EXISTS select_jobs ON public.jobs;

CREATE POLICY select_jobs ON public.jobs
FOR SELECT
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- 4. users SELECT 정책 (공개 프로필 조회 가능)
DROP POLICY IF EXISTS select_users ON public.users;

CREATE POLICY select_users ON public.users
FOR SELECT
TO authenticated, anon
USING (true);

SELECT '✅ SELECT RLS 정책 추가 완료!' AS result;


-- 사업자 승인 상태 RLS 정책 강화
-- Supabase SQL Editor에서 실행
-- 승인된 사업자만 특정 작업을 수행할 수 있도록 제한

-- ============================================
-- 1. marketplace_listings (오더 마켓플레이스)
-- ============================================

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_marketplace_listings ON public.marketplace_listings;

-- 새 INSERT 정책: 승인된 사업자만 오더 생성 가능
CREATE POLICY ins_marketplace_listings ON public.marketplace_listings
FOR INSERT
TO authenticated
WITH CHECK (
  posted_by::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id::text = (auth.uid())::text
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

-- ============================================
-- 2. order_bids (입찰)
-- ============================================

-- 기존 INSERT 정책 확인
SELECT '=== order_bids 정책 확인 ===' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'order_bids' AND cmd = 'INSERT'
ORDER BY policyname;

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_order_bids ON public.order_bids;
DROP POLICY IF EXISTS insert_order_bids ON public.order_bids;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.order_bids;

-- 새 INSERT 정책: 승인된 사업자만 입찰 가능
CREATE POLICY ins_order_bids ON public.order_bids
FOR INSERT
TO authenticated
WITH CHECK (
  bidder_id::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id::text = (auth.uid())::text
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

-- ============================================
-- 3. estimates (견적서)
-- ============================================

-- 기존 INSERT 정책 확인
SELECT '=== estimates 정책 확인 ===' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'estimates' AND cmd = 'INSERT'
ORDER BY policyname;

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_estimates ON public.estimates;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.estimates;

-- 새 INSERT 정책: 승인된 사업자만 견적서 생성 가능
CREATE POLICY ins_estimates ON public.estimates
FOR INSERT
TO authenticated
WITH CHECK (
  businessid::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id::text = (auth.uid())::text
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

-- ============================================
-- 4. jobs (공사 등록)
-- ============================================

-- 기존 INSERT 정책 확인
SELECT '=== jobs 정책 확인 ===' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'jobs' AND cmd = 'INSERT'
ORDER BY policyname;

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_jobs ON public.jobs;
DROP POLICY IF EXISTS "Business users can create jobs" ON public.jobs;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.jobs;

-- 새 INSERT 정책: 승인된 사업자만 공사 등록 가능
CREATE POLICY ins_jobs ON public.jobs
FOR INSERT
TO authenticated
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id::text = (auth.uid())::text
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

-- ============================================
-- 5. 정책 확인
-- ============================================

SELECT '=== ✅ 업데이트된 정책 확인 ===' as info;

SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%businessstatus%' THEN '✅ 승인 체크 포함'
    ELSE '⚠️ 승인 체크 없음'
  END as approval_check
FROM pg_policies
WHERE tablename IN ('marketplace_listings', 'order_bids', 'estimates', 'jobs')
  AND cmd = 'INSERT'
ORDER BY tablename, policyname;

-- ============================================
-- 6. 테스트 쿼리 (선택사항)
-- ============================================

-- 현재 사용자의 승인 상태 확인
SELECT '=== 현재 사용자 승인 상태 ===' as info;
SELECT id, name, role, businessstatus
FROM public.users
WHERE id::text = (auth.uid())::text;

-- 승인되지 않은 사업자 목록
SELECT '=== 승인 대기 중인 사업자 ===' as info;
SELECT id, name, email, businessname, role, businessstatus, createdat
FROM public.users
WHERE role = 'business' 
  AND (businessstatus IS NULL OR businessstatus = 'pending')
ORDER BY createdat DESC;


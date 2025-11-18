-- ==========================================
-- 🚨 긴급 RLS 및 제약조건 수정
-- Supabase SQL Editor에서 이 파일 전체를 실행하세요!
-- ==========================================

-- ==========================================
-- 1. order_bids DELETE 정책 추가
-- ==========================================
DROP POLICY IF EXISTS delete_order_bids ON public.order_bids;

CREATE POLICY delete_order_bids ON public.order_bids
FOR DELETE
TO authenticated, anon
USING (
  bidder_id = auth.uid() 
  OR auth.uid() IS NULL  -- anon 사용자 허용
);

-- ==========================================
-- 2. marketplace_listings UPDATE 정책 수정
-- ==========================================
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;

CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by = auth.uid()
  OR claimed_by = auth.uid()
  OR selected_bidder_id = auth.uid()
  OR auth.uid() IS NULL  -- anon 허용
  OR EXISTS (
    SELECT 1 FROM jobs j
    WHERE j.id = jobid 
      AND (j.owner_business_id = auth.uid() OR j.assigned_business_id = auth.uid())
  )
)
WITH CHECK (
  posted_by = auth.uid()
  OR claimed_by = auth.uid()
  OR selected_bidder_id = auth.uid()
  OR auth.uid() IS NULL
  OR EXISTS (
    SELECT 1 FROM jobs j
    WHERE j.id = jobid 
      AND (j.owner_business_id = auth.uid() OR j.assigned_business_id = auth.uid())
  )
);

-- ==========================================
-- 3. jobs UPDATE 정책 수정
-- ==========================================
DROP POLICY IF EXISTS update_jobs ON public.jobs;

CREATE POLICY update_jobs ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  owner_business_id = auth.uid()
  OR assigned_business_id = auth.uid()
  OR auth.uid() IS NULL  -- anon 허용
)
WITH CHECK (
  owner_business_id = auth.uid()
  OR assigned_business_id = auth.uid()
  OR auth.uid() IS NULL
);

-- ==========================================
-- 4. jobs status CHECK 제약조건 수정
-- ==========================================
ALTER TABLE public.jobs DROP CONSTRAINT IF EXISTS jobs_status_check;

ALTER TABLE public.jobs ADD CONSTRAINT jobs_status_check 
CHECK (status IN (
  'created', 
  'pending_transfer', 
  'assigned', 
  'in_progress',
  'awaiting_confirmation',  -- ✅ 추가 (공사 완료 대기)
  'completed', 
  'cancelled'
));

-- ==========================================
-- 확인
-- ==========================================
SELECT '=== order_bids 정책 ===' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'order_bids' ORDER BY cmd;

SELECT '=== marketplace_listings 정책 ===' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'marketplace_listings' ORDER BY cmd;

SELECT '=== jobs 정책 ===' as info;
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'jobs' ORDER BY cmd;

SELECT '=== jobs CHECK 제약조건 ===' as info;
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'jobs'::regclass AND contype = 'c' AND conname = 'jobs_status_check';

SELECT '✅✅✅ 모든 RLS 및 제약조건 수정 완료! ✅✅✅' as status;


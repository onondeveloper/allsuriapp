-- ==========================================
-- 🚨 최종 RLS 정책 수정 (완전 정리)
-- 모든 중복 정책 제거 후 재생성
-- ==========================================

-- ==========================================
-- 1. marketplace_listings - 모든 UPDATE 정책 삭제
-- ==========================================
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS upd_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS update_marketplace_listings_policy ON public.marketplace_listings;
DROP POLICY IF EXISTS "Business can update their listings" ON public.marketplace_listings;
DROP POLICY IF EXISTS "Enable update for users based on id" ON public.marketplace_listings;

-- 새로운 UPDATE 정책 생성 (단일)
CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- ==========================================
-- 2. jobs - 모든 UPDATE 정책 삭제
-- ==========================================
DROP POLICY IF EXISTS update_jobs ON public.jobs;
DROP POLICY IF EXISTS update_jobs_policy ON public.jobs;
DROP POLICY IF EXISTS upd_jobs ON public.jobs;
DROP POLICY IF EXISTS "Job owners can update their jobs" ON public.jobs;
DROP POLICY IF EXISTS "Enable update for users based on id" ON public.jobs;

-- 새로운 UPDATE 정책 생성 (단일)
CREATE POLICY update_jobs ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- ==========================================
-- 3. 정책 확인
-- ==========================================
SELECT '=== marketplace_listings UPDATE 정책 (단일이어야 함) ===' as info;
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'marketplace_listings' AND cmd = 'UPDATE';

SELECT '=== jobs UPDATE 정책 (단일이어야 함) ===' as info;
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'jobs' AND cmd = 'UPDATE';

-- ==========================================
-- 4. Realtime 활성화 확인 및 추가
-- ==========================================
DO $$
BEGIN
  -- marketplace_listings Realtime 활성화
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'marketplace_listings already in supabase_realtime';
  END;
  
  -- order_bids Realtime 활성화
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'order_bids already in supabase_realtime';
  END;
  
  -- jobs Realtime 활성화
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'jobs already in supabase_realtime';
  END;
END $$;

-- Realtime 활성화 확인
SELECT '=== Realtime 활성화된 테이블 ===' as info;
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('marketplace_listings', 'order_bids', 'jobs');

-- ==========================================
-- 5. 테스트 쿼리 (현재 사용자 ID로 테스트)
-- ==========================================
-- 아래 쿼리에서 'your-user-id'를 실제 사용자 ID로 변경하여 테스트하세요

/*
-- 예시: claimed_by 사용자가 업데이트 가능한지 테스트
SELECT 
  id,
  title,
  status,
  posted_by,
  claimed_by,
  completed_by
FROM marketplace_listings
WHERE claimed_by = 'your-user-id';

-- 위 오더를 업데이트할 수 있는지 테스트
UPDATE marketplace_listings
SET status = 'awaiting_confirmation',
    completed_by = 'your-user-id',
    completed_at = NOW()
WHERE id = 'test-listing-id'
  AND claimed_by = 'your-user-id';
*/

SELECT '✅ RLS 정책 완전 정리 완료!' AS status;
SELECT '📋 위의 확인 결과를 검토하고, 각 테이블에 UPDATE 정책이 1개씩만 있는지 확인하세요.' AS note;


-- marketplace_listings UPDATE RLS 정책 수정
-- 문제: 공사 완료 시 status 업데이트가 차단됨
-- 해결: UPDATE 정책 추가/수정

-- 1. 기존 UPDATE 정책 확인
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'marketplace_listings' AND cmd = 'UPDATE';

-- 2. 기존 UPDATE 정책 삭제
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;

-- 3. 새로운 UPDATE 정책: 소유자, 낙찰자, 또는 claimed_by 사용자가 업데이트 가능
CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by = auth.uid()  -- 오더 소유자
  OR claimed_by = auth.uid()  -- 오더를 가져간 사업자
  OR selected_bidder_id = auth.uid()  -- 선택된 입찰자
  OR auth.uid() IS NULL  -- anon 사용자 (Supabase 세션 없는 경우)
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

-- 4. jobs UPDATE RLS 정책도 확인/수정
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

-- 5. 정책 확인
SELECT '=== marketplace_listings UPDATE 정책 ===' as info;
SELECT 
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'marketplace_listings' AND cmd = 'UPDATE';

SELECT '=== jobs UPDATE 정책 ===' as info;
SELECT 
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'jobs' AND cmd = 'UPDATE';

SELECT '✅ RLS UPDATE 정책 수정 완료!' as status;


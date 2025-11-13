-- marketplace_listings RLS 정책 수정
-- assigned 된 공사도 조회할 수 있도록 수정

-- 기존 정책 삭제
DROP POLICY IF EXISTS sel_marketplace_listings ON public.marketplace_listings;

-- 새 정책 생성
-- 조건:
-- 1. status가 open, created, withdrawn인 경우 (모두 볼 수 있음)
-- 2. 내가 올린 것 (posted_by = auth.uid())
-- 3. 내가 입찰한 것 (claimed_by = auth.uid())
-- 4. 내가 선택된 입찰자인 것 (selected_bidder_id = auth.uid())
-- 5. 내가 assigned된 공사 (jobs.assigned_business_id = auth.uid())
CREATE POLICY sel_marketplace_listings ON public.marketplace_listings
FOR SELECT
TO authenticated, anon
USING (
  status IN ('open', 'created', 'withdrawn') 
  OR posted_by = auth.uid() 
  OR claimed_by = auth.uid()
  OR selected_bidder_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM jobs 
    WHERE jobs.id = marketplace_listings.jobid 
      AND jobs.assigned_business_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM jobs 
    WHERE jobs.id = marketplace_listings.jobid 
      AND jobs.owner_business_id = auth.uid()
  )
);

SELECT '✅ marketplace_listings RLS 정책 업데이트 완료' AS status;

-- 테스트 쿼리: 현재 사용자로 조회 가능한 listings 확인
-- SELECT id, jobid, title, status, claimed_by
-- FROM marketplace_listings
-- WHERE jobid IN ('d1d7ffc2-2aa1-421a-9ae4-2264183b5a89', '018a7a90-403b-4e2d-a2df-827da302dd81');


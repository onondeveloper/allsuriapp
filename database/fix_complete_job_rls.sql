-- ==========================================
-- 🚨 긴급: 공사 완료 RLS 정책 수정
-- 문제: claimed_by 사용자가 marketplace_listings와 jobs를 업데이트할 수 없음
-- 해결: UPDATE 정책에 claimed_by와 assigned_business_id 사용자 권한 추가
-- ==========================================

-- ==========================================
-- 1. marketplace_listings UPDATE 정책 수정
-- ==========================================
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;

CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text  -- 오더 소유자
  OR claimed_by::text = (auth.uid())::text  -- 오더를 가져간 사업자 (★ 이게 중요!)
  OR selected_bidder_id::text = (auth.uid())::text  -- 선택된 입찰자
  OR auth.uid() IS NULL  -- anon 사용자 허용
  OR EXISTS (
    SELECT 1 FROM jobs j
    WHERE j.id = jobid 
      AND (j.owner_business_id::text = (auth.uid())::text 
           OR j.assigned_business_id::text = (auth.uid())::text)
  )
)
WITH CHECK (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text  -- ★ 이것도 중요!
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
  OR EXISTS (
    SELECT 1 FROM jobs j
    WHERE j.id = jobid 
      AND (j.owner_business_id::text = (auth.uid())::text 
           OR j.assigned_business_id::text = (auth.uid())::text)
  )
);

-- ==========================================
-- 2. jobs UPDATE 정책 수정
-- ==========================================
DROP POLICY IF EXISTS update_jobs ON public.jobs;

CREATE POLICY update_jobs ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text  -- 공사 소유자
  OR assigned_business_id::text = (auth.uid())::text  -- 배정된 사업자 (★ 이게 중요!)
  OR auth.uid() IS NULL  -- anon 사용자 허용
)
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text  -- ★ 이것도 중요!
  OR auth.uid() IS NULL
);

-- ==========================================
-- 3. chat_rooms 스키마 수정
-- estimateid를 nullable로 변경 (오더 시스템 지원)
-- ==========================================

-- estimateid의 NOT NULL 제약 제거
ALTER TABLE public.chat_rooms
ALTER COLUMN estimateid DROP NOT NULL;

-- listingid 컬럼이 없으면 추가
ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS listingid UUID REFERENCES marketplace_listings(id) ON DELETE CASCADE;

-- participant_a, participant_b 컬럼이 없으면 추가
ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS participant_a UUID REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS participant_b UUID REFERENCES users(id) ON DELETE CASCADE;

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_chat_rooms_listingid ON chat_rooms(listingid);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_a ON chat_rooms(participant_a);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_b ON chat_rooms(participant_b);

-- ==========================================
-- 4. chat_rooms RLS 정책 업데이트
-- ==========================================

-- SELECT 정책
DROP POLICY IF EXISTS select_chat_rooms ON public.chat_rooms;
CREATE POLICY select_chat_rooms ON public.chat_rooms
FOR SELECT
TO authenticated, anon
USING (
  participant_a::text = (auth.uid())::text
  OR participant_b::text = (auth.uid())::text
  OR customerid::text = (auth.uid())::text
  OR businessid::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- INSERT 정책
DROP POLICY IF EXISTS insert_chat_rooms ON public.chat_rooms;
CREATE POLICY insert_chat_rooms ON public.chat_rooms
FOR INSERT
TO authenticated, anon
WITH CHECK (
  participant_a::text = (auth.uid())::text
  OR participant_b::text = (auth.uid())::text
  OR customerid::text = (auth.uid())::text
  OR businessid::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- UPDATE 정책
DROP POLICY IF EXISTS update_chat_rooms ON public.chat_rooms;
CREATE POLICY update_chat_rooms ON public.chat_rooms
FOR UPDATE
TO authenticated, anon
USING (
  participant_a::text = (auth.uid())::text
  OR participant_b::text = (auth.uid())::text
  OR customerid::text = (auth.uid())::text
  OR businessid::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- ==========================================
-- 5. 정책 확인
-- ==========================================
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

SELECT '=== chat_rooms 스키마 ===' as info;
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'chat_rooms'
  AND column_name IN ('estimateid', 'listingid', 'participant_a', 'participant_b')
ORDER BY ordinal_position;

SELECT '✅ 모든 RLS 정책 및 스키마 업데이트 완료!' as status;


-- ==========================================
-- 🔧 order_reviews RLS 정책 수정
-- 리뷰 작성 권한 추가
-- ==========================================

-- 1. 현재 order_reviews RLS 정책 확인
SELECT '=== 현재 order_reviews RLS 정책 ===' as info;
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'order_reviews'
ORDER BY cmd;

-- 2. 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS insert_order_reviews ON public.order_reviews;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.order_reviews;
DROP POLICY IF EXISTS "Users can insert their own reviews" ON public.order_reviews;

-- 3. 새로운 INSERT 정책 생성
-- 로그인한 사용자가 리뷰를 작성한 사람이면 INSERT 가능
CREATE POLICY insert_order_reviews ON public.order_reviews
FOR INSERT
TO authenticated, anon
WITH CHECK (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- 4. UPDATE 정책도 확인 및 수정
DROP POLICY IF EXISTS update_order_reviews ON public.order_reviews;
DROP POLICY IF EXISTS "Users can update their own reviews" ON public.order_reviews;

CREATE POLICY update_order_reviews ON public.order_reviews
FOR UPDATE
TO authenticated, anon
USING (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- 5. SELECT 정책 확인
DROP POLICY IF EXISTS select_order_reviews ON public.order_reviews;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.order_reviews;

CREATE POLICY select_order_reviews ON public.order_reviews
FOR SELECT
TO authenticated, anon
USING (true);  -- 모든 사용자가 리뷰 조회 가능

-- 6. DELETE 정책
DROP POLICY IF EXISTS delete_order_reviews ON public.order_reviews;

CREATE POLICY delete_order_reviews ON public.order_reviews
FOR DELETE
TO authenticated, anon
USING (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- 7. 수정된 RLS 정책 확인
SELECT '=== 수정된 order_reviews RLS 정책 ===' as info;
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN cmd = 'INSERT' THEN 'WITH CHECK: reviewer_id = auth.uid()'
        WHEN cmd = 'UPDATE' THEN 'USING & WITH CHECK: reviewer_id = auth.uid()'
        WHEN cmd = 'SELECT' THEN 'USING: true (모든 사용자)'
        WHEN cmd = 'DELETE' THEN 'USING: reviewer_id = auth.uid()'
    END as description
FROM pg_policies
WHERE tablename = 'order_reviews'
ORDER BY cmd;

-- 8. RLS 활성화 확인
SELECT '=== RLS 활성화 상태 ===' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'order_reviews';

-- RLS가 비활성화되어 있다면 활성화
ALTER TABLE public.order_reviews ENABLE ROW LEVEL SECURITY;

SELECT '✅ order_reviews RLS 정책 수정 완료!' AS result;
SELECT '📋 이제 리뷰 작성이 가능합니다!' AS note;


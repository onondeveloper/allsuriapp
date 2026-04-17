-- ==========================================
-- 웹 비로그인 견적 요청 + 사업자 목록 활성화
-- allsuri-web 에서 로그인 없이 이용 가능하도록 설정
--
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ==========================================

-- ==========================================
-- 1. users 테이블: anon이 사업자 목록 조회 가능하도록
--    (role='business', businessstatus='approved' 인 행만 노출)
-- ==========================================
DROP POLICY IF EXISTS "anon_read_business_users" ON public.users;

CREATE POLICY "anon_read_business_users" ON public.users
FOR SELECT
TO anon
USING (
  role = 'business'
  AND businessstatus = 'approved'
);

-- ==========================================
-- 2. business_reviews 테이블: anon SELECT 허용 (평점 표시용)
-- ==========================================
DROP POLICY IF EXISTS "anon_read_business_reviews" ON public.business_reviews;

CREATE POLICY "anon_read_business_reviews" ON public.business_reviews
FOR SELECT
TO anon
USING (true);

-- ==========================================
-- 3. orders 테이블: anon INSERT 허용
--    (isAnonymous = true 인 웹 견적 요청)
-- ==========================================
DROP POLICY IF EXISTS "anon_web_orders_insert" ON public.orders;

CREATE POLICY "anon_web_orders_insert" ON public.orders
FOR INSERT
TO anon
WITH CHECK ("isAnonymous" = true);

-- authenticated INSERT 정책 (없으면 생성)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'orders' AND cmd = 'INSERT'
      AND roles::text LIKE '%authenticated%'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "authenticated_orders_insert" ON public.orders
      FOR INSERT TO authenticated WITH CHECK (true);
    $pol$;
    RAISE NOTICE 'authenticated_orders_insert 정책 생성됨';
  END IF;
END $$;

-- ==========================================
-- 4. attachments_estimates 스토리지: anon 업로드 허용
--    (웹 폼 사진 첨부)
-- ==========================================
DROP POLICY IF EXISTS "Allow anon uploads to attachments_estimates" ON storage.objects;

CREATE POLICY "Allow anon uploads to attachments_estimates"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (bucket_id = 'attachments_estimates');

-- ==========================================
-- 5. 결과 확인
-- ==========================================
SELECT '=== users 테이블 anon 정책 ===' AS info;
SELECT policyname, cmd, roles
FROM pg_policies WHERE tablename = 'users' AND roles::text LIKE '%anon%';

SELECT '=== business_reviews anon 정책 ===' AS info;
SELECT policyname, cmd, roles
FROM pg_policies WHERE tablename = 'business_reviews' AND roles::text LIKE '%anon%';

SELECT '=== orders anon 정책 ===' AS info;
SELECT policyname, cmd, roles
FROM pg_policies WHERE tablename = 'orders' AND roles::text LIKE '%anon%';

SELECT '=== 등록된 사업자 수 ===' AS info;
SELECT COUNT(*) AS approved_businesses
FROM users WHERE role = 'business' AND businessstatus = 'approved';

SELECT '✅ 웹 서비스 RLS 설정 완료!' AS status;

-- ==========================================
-- 웹 비로그인 견적 요청 활성화
-- allsuri-web (/requests 페이지) 에서 로그인 없이 주문 생성 가능하도록 설정
--
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ==========================================

-- ==========================================
-- 1. orders 테이블: anon INSERT 허용
--    (isAnonymous = true 인 경우만)
-- ==========================================
DROP POLICY IF EXISTS "anon_web_orders_insert" ON public.orders;
DROP POLICY IF EXISTS "Allow anon insert orders"  ON public.orders;

CREATE POLICY "anon_web_orders_insert" ON public.orders
FOR INSERT
TO anon
WITH CHECK ("isAnonymous" = true);

-- ==========================================
-- 2. orders 테이블: authenticated INSERT 도 유지 (앱 사용자)
-- ==========================================
-- 기존 authenticated 정책이 없으면 생성
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'orders'
      AND cmd = 'INSERT'
      AND roles::text LIKE '%authenticated%'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "authenticated_orders_insert" ON public.orders
      FOR INSERT
      TO authenticated
      WITH CHECK (true);
    $pol$;
    RAISE NOTICE 'authenticated_orders_insert 정책 생성됨';
  ELSE
    RAISE NOTICE 'authenticated INSERT 정책이 이미 있습니다';
  END IF;
END $$;

-- ==========================================
-- 3. orders 테이블: anon SELECT (본인 것만, isAnonymous = true 허용)
--    앱에서 조회하는 authenticated SELECT 정책도 확인
-- ==========================================
DROP POLICY IF EXISTS "anon_web_orders_select" ON public.orders;

CREATE POLICY "anon_web_orders_select" ON public.orders
FOR SELECT
TO anon
USING ("isAnonymous" = true);

-- ==========================================
-- 4. attachments_estimates 스토리지: anon 업로드 허용
--    (웹 폼에서 사진 첨부 기능)
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
SELECT '=== orders 테이블 RLS 정책 ===' AS info;
SELECT
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'orders'
ORDER BY cmd, roles::text;

SELECT '=== attachments_estimates 스토리지 정책 ===' AS info;
SELECT
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (qual  LIKE '%attachments_estimates%'
       OR with_check LIKE '%attachments_estimates%')
ORDER BY cmd;

SELECT '✅ 웹 비로그인 견적 요청 RLS 설정 완료!' AS status;
SELECT '👉 이제 allsuri-web /requests 페이지에서 로그인 없이 견적 요청이 가능합니다.' AS note;

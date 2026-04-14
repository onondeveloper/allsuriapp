-- ==========================================
-- attachments_estimates 버킷 RLS 정책 수정
-- Supabase Dashboard → SQL Editor에서 실행하세요.
--
-- 원인: INSERT 정책의 WITH CHECK에 추가 조건이 있어
--       path 구조나 owner 조건이 실제 업로드와 맞지 않아 403 발생.
-- ==========================================

-- 1) 기존 INSERT 정책 모두 제거 (attachments_estimates)
DROP POLICY IF EXISTS "Allow authenticated uploads to attachments_estimates" ON storage.objects;
DROP POLICY IF EXISTS "Allow anon uploads to attachments_estimates"          ON storage.objects;
DROP POLICY IF EXISTS "attachments_estimates_insert"                         ON storage.objects;

-- 2) 인증된 사용자가 어떤 경로/파일명으로든 업로드 가능하도록 재생성
CREATE POLICY "Allow authenticated uploads to attachments_estimates"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'attachments_estimates');

-- 3) 익명 사용자 업로드는 허용하지 않음 (보안 강화)
--    만약 anon 업로드도 필요하면 아래 주석 해제
-- CREATE POLICY "Allow anon uploads to attachments_estimates"
-- ON storage.objects
-- FOR INSERT
-- TO anon
-- WITH CHECK (bucket_id = 'attachments_estimates');

-- 4) SELECT 정책 확인 (없으면 재생성)
DROP POLICY IF EXISTS "Allow public read from attachments_estimates" ON storage.objects;
DROP POLICY IF EXISTS "attachments_estimates_select"                ON storage.objects;

CREATE POLICY "Allow public read from attachments_estimates"
ON storage.objects
FOR SELECT
TO authenticated, anon
USING (bucket_id = 'attachments_estimates');

-- 5) UPDATE/DELETE 정책 (자신이 올린 파일만 수정/삭제 가능)
DROP POLICY IF EXISTS "attachments_estimates_update" ON storage.objects;
DROP POLICY IF EXISTS "attachments_estimates_delete" ON storage.objects;

CREATE POLICY "attachments_estimates_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING     (bucket_id = 'attachments_estimates' AND owner_id = auth.uid()::text)
WITH CHECK (bucket_id = 'attachments_estimates' AND owner_id = auth.uid()::text);

CREATE POLICY "attachments_estimates_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'attachments_estimates' AND owner_id = auth.uid()::text);

-- 6) 결과 확인
SELECT
  policyname,
  cmd,
  roles,
  permissive,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename  = 'objects'
  AND (qual LIKE '%attachments_estimates%' OR with_check LIKE '%attachments_estimates%')
ORDER BY cmd;

SELECT '✅ attachments_estimates 정책 설정 완료' AS status;

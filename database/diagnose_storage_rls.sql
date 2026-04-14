-- ==========================================
-- Storage RLS 정책 전체 진단
-- Supabase SQL Editor (postgres 계정)에서 실행
-- ==========================================

-- 1) storage.objects의 모든 정책 상세 확인 (WITH CHECK 포함)
SELECT
  policyname,
  cmd,
  roles,
  permissive,
  qual       AS using_clause,
  with_check AS with_check_clause
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename  = 'objects'
ORDER BY cmd, policyname;

-- 2) attachments_estimates 버킷 설정 확인
SELECT
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE id = 'attachments_estimates';

-- 3) 현재 실행 계정 확인
SELECT current_user, session_user;

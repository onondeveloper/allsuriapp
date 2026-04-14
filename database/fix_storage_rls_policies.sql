-- Storage 버킷/RLS 정책 일괄 복구
-- Supabase SQL Editor에서 한 번에 실행하세요.

-- 1) 버킷 존재 보장 (없으면 생성, 있으면 공개/제한값 갱신)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'attachments_messages',
    'attachments_messages',
    true,
    52428800,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime']
  ),
  (
    'attachments_estimates',
    'attachments_estimates',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'profiles',
    'profiles',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'public',
    'public',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  )
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2) 권한 문제(42501) 회피:
--    현재 계정이 storage.objects 테이블 owner가 아니면 정책 DDL(DROP/CREATE POLICY)을 실행할 수 없습니다.
--    아래 스크립트는 "버킷 존재/설정"만 맞추고, 정책은 조회만 합니다.

-- 3) 현재 권한/소유자/정책 상태 확인
SELECT current_user AS running_as;

SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  pg_get_userbyid(c.relowner) AS table_owner
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'storage'
  AND c.relname = 'objects';

SELECT
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
ORDER BY policyname;

-- 4) 결과 확인
SELECT '✅ 버킷 설정 완료 (정책 DDL은 권한 있는 계정으로 별도 실행 필요)' AS status;

SELECT id, public, file_size_limit
FROM storage.buckets
WHERE id IN ('attachments_messages', 'attachments_estimates', 'profiles', 'public')
ORDER BY id;

SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
ORDER BY policyname;


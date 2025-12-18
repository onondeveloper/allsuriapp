-- Storage 완전 수정 (모든 정책 제거 후 재생성)
-- Supabase SQL Editor에서 실행하세요

-- 1단계: 모든 기존 정책 삭제
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
        RAISE NOTICE 'Dropped policy: %', r.policyname;
    END LOOP;
END $$;

-- 2단계: RLS 활성화 확인
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3단계: 새로운 정책 생성

-- attachments_messages 버킷 정책 (인증된 사용자 모두 허용)
CREATE POLICY "attachments_messages_insert" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'attachments_messages');

CREATE POLICY "attachments_messages_select" 
ON storage.objects
FOR SELECT 
TO authenticated, anon
USING (bucket_id = 'attachments_messages');

CREATE POLICY "attachments_messages_update" 
ON storage.objects
FOR UPDATE 
TO authenticated
USING (bucket_id = 'attachments_messages')
WITH CHECK (bucket_id = 'attachments_messages');

CREATE POLICY "attachments_messages_delete" 
ON storage.objects
FOR DELETE 
TO authenticated
USING (bucket_id = 'attachments_messages');

-- attachments_estimates 버킷 정책
CREATE POLICY "attachments_estimates_insert" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'attachments_estimates');

CREATE POLICY "attachments_estimates_select" 
ON storage.objects
FOR SELECT 
TO authenticated, anon
USING (bucket_id = 'attachments_estimates');

-- profiles 버킷 정책
CREATE POLICY "profiles_insert" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'profiles');

CREATE POLICY "profiles_select" 
ON storage.objects
FOR SELECT 
TO authenticated, anon
USING (bucket_id = 'profiles');

-- public 버킷 정책
CREATE POLICY "public_insert" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'public');

CREATE POLICY "public_select" 
ON storage.objects
FOR SELECT 
TO authenticated, anon
USING (bucket_id = 'public');

-- 4단계: 확인
SELECT '✅ Storage RLS 정책 설정 완료' AS status;

-- 생성된 정책 확인
SELECT 
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
ORDER BY policyname;


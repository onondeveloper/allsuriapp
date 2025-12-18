-- Storage RLS 정책 수정
-- Supabase SQL Editor에서 실행하세요

-- 기존 정책 모두 삭제
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads estimates" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read estimates" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads profiles" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read profiles" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads public" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read public bucket" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to attachments_messages" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from attachments_messages" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update to attachments_messages" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete from attachments_messages" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to attachments_estimates" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from attachments_estimates" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to profiles" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from profiles" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to public" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read from public bucket" ON storage.objects;

-- attachments_messages 버킷 정책
CREATE POLICY "Allow authenticated uploads to attachments_messages" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'attachments_messages');

CREATE POLICY "Allow public read from attachments_messages" 
ON storage.objects
FOR SELECT 
TO public
USING (bucket_id = 'attachments_messages');

CREATE POLICY "Allow authenticated update to attachments_messages" 
ON storage.objects
FOR UPDATE 
TO authenticated
USING (bucket_id = 'attachments_messages');

CREATE POLICY "Allow authenticated delete from attachments_messages" 
ON storage.objects
FOR DELETE 
TO authenticated
USING (bucket_id = 'attachments_messages');

-- attachments_estimates 버킷 정책
CREATE POLICY "Allow authenticated uploads to attachments_estimates" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'attachments_estimates');

CREATE POLICY "Allow public read from attachments_estimates" 
ON storage.objects
FOR SELECT 
TO public
USING (bucket_id = 'attachments_estimates');

-- profiles 버킷 정책
CREATE POLICY "Allow authenticated uploads to profiles" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'profiles');

CREATE POLICY "Allow public read from profiles" 
ON storage.objects
FOR SELECT 
TO public
USING (bucket_id = 'profiles');

-- public 버킷 정책
CREATE POLICY "Allow authenticated uploads to public" 
ON storage.objects
FOR INSERT 
TO authenticated
WITH CHECK (bucket_id = 'public');

CREATE POLICY "Allow public read from public bucket" 
ON storage.objects
FOR SELECT 
TO public
USING (bucket_id = 'public');

SELECT '✅ Storage RLS 정책 설정 완료' AS status;


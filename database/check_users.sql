-- ============================================
-- Supabase 사용자 테이블 확인 쿼리
-- ============================================

-- 1. 모든 사용자 목록 확인 (최신순)
SELECT 
    id,
    name,
    email,
    role,
    businessname,
    businessstatus,
    createdat,
    external_id,
    provider
FROM users
ORDER BY createdat DESC
LIMIT 20;

-- 2. 사업자 사용자만 확인
SELECT 
    id,
    name,
    email,
    businessname,
    businessnumber,
    businessstatus,
    phonenumber,
    createdat
FROM users
WHERE role = 'business'
ORDER BY createdat DESC;

-- 3. 승인 대기 중인 사업자 확인
SELECT 
    id,
    name,
    email,
    businessname,
    businessstatus,
    createdat
FROM users
WHERE role = 'business' 
  AND businessstatus = 'pending'
ORDER BY createdat DESC;

-- 4. 카카오 로그인 사용자 확인
SELECT 
    id,
    name,
    email,
    provider,
    external_id,
    role,
    createdat
FROM users
WHERE provider = 'kakao' 
   OR external_id LIKE 'kakao:%'
ORDER BY createdat DESC;

-- 5. 테이블 구조 확인
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 6. 최근 생성된 사용자 (마지막 1시간)
SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    createdat
FROM users
WHERE createdat > NOW() - INTERVAL '1 hour'
ORDER BY createdat DESC;


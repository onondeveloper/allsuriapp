-- NULL 상태 사용자 수정 SQL
-- Supabase SQL Editor에서 실행하세요

-- 1. 현재 NULL 상태인 사용자 확인
SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    kakao_id,
    external_id,
    createdat
FROM users
WHERE businessstatus IS NULL
ORDER BY createdat DESC;

-- 2. 카카오 사용자(4479276246)의 상태를 'pending'으로 업데이트
UPDATE users
SET 
    businessstatus = 'pending'::business_status,
    role = 'business'
WHERE kakao_id = '4479276246'
   OR external_id LIKE '%4479276246%';

-- 3. 모든 NULL 상태 사용자를 기본값으로 업데이트
UPDATE users
SET 
    businessstatus = CASE 
        WHEN role = 'business' THEN 'pending'::business_status
        ELSE NULL
    END
WHERE businessstatus IS NULL AND role = 'business';

-- 4. 결과 확인
SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    kakao_id,
    createdat
FROM users
WHERE kakao_id = '4479276246'
   OR external_id LIKE '%4479276246%';

-- 완료 메시지
SELECT '✅ NULL 사용자 상태 수정 완료' AS status;



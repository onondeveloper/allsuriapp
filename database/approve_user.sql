-- 사용자 승인 및 상태 확인 SQL

-- 1. 현재 "개발자" 사용자 상태 확인
SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    businessname,
    kakao_id,
    createdat
FROM users
WHERE name = '개발자' OR kakao_id = '4479276246';

-- 2. "개발자" 사용자 강제 승인
UPDATE users
SET businessstatus = 'approved'
WHERE name = '개발자' OR kakao_id = '4479276246';

-- 3. 업데이트 결과 확인
SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    businessname,
    kakao_id,
    createdat,
    updatedat
FROM users
WHERE name = '개발자' OR kakao_id = '4479276246';

-- 4. 모든 승인된 사업자 확인
SELECT 
    id,
    name,
    businessname,
    businessstatus,
    createdat
FROM users
WHERE role = 'business' AND businessstatus = 'approved'
ORDER BY createdat DESC;

-- 완료 메시지
SELECT '✅ 사용자 승인 완료 - 앱을 재시작하면 승인된 상태로 로그인됩니다' AS status;


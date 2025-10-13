-- ========================================
-- 특정 사업자만 유지하고 모든 데이터 삭제
-- ========================================
-- 사용법: 아래 유지할 사업자의 ID나 이메일을 수정하세요

BEGIN;

-- 🔍 현재 모든 사업자 계정 확인
SELECT 
    '📋 현재 사업자 계정 목록:' AS info,
    id,
    name,
    email,
    businessname,
    businessstatus,
    created_at
FROM users 
WHERE role = 'business'
ORDER BY created_at DESC;

-- ⚠️ 유지할 사업자 ID 또는 이메일을 아래에 지정하세요
-- 예: WHERE id = 'kakao:4479276246' OR email = 'business@example.com'
WITH businesses_to_keep AS (
    SELECT id FROM users 
    WHERE role = 'business'
    -- 👇 유지할 사업자 조건을 여기에 추가하세요
    -- AND (
    --     id = 'kakao:4479276246' 
    --     OR email = 'your-business@example.com'
    --     OR businessname = '테스트 업체'
    -- )
)
SELECT 
    '🔒 유지될 사업자:' AS status,
    u.id,
    u.name,
    u.email,
    u.businessname
FROM users u
WHERE u.id IN (SELECT id FROM businesses_to_keep);

-- 삭제될 데이터 확인
SELECT 
    '🗑️ 삭제될 사용자 (사업자 포함):' AS warning,
    COUNT(*) AS count
FROM users 
WHERE id NOT IN (SELECT id FROM businesses_to_keep);

-- ⚠️ 아래 주석을 해제하여 실제 삭제를 실행하세요
/*
-- 데이터 삭제 (유지할 사업자 제외, 실제 컬럼명 사용)
DELETE FROM community_comments WHERE authorid NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM community_posts WHERE authorid NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM marketplace_listings WHERE posted_by NOT IN (SELECT id FROM businesses_to_keep) OR claimed_by NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM notifications WHERE userid NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM jobs WHERE owner_business_id NOT IN (SELECT id FROM businesses_to_keep) 
    OR assigned_business_id NOT IN (SELECT id FROM businesses_to_keep) 
    OR transfer_to_business_id NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM chat_rooms WHERE (customerid NOT IN (SELECT id FROM businesses_to_keep)) OR (businessid NOT IN (SELECT id FROM businesses_to_keep));
DELETE FROM messages WHERE senderid NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM estimates WHERE (customerid NOT IN (SELECT id FROM businesses_to_keep)) OR (businessid NOT IN (SELECT id FROM businesses_to_keep));
DELETE FROM orders WHERE ("customerId" NOT IN (SELECT id FROM businesses_to_keep)) OR ("businessId" NOT IN (SELECT id FROM businesses_to_keep));
DELETE FROM profile_media WHERE userid NOT IN (SELECT id FROM businesses_to_keep);
DELETE FROM users WHERE id NOT IN (SELECT id FROM businesses_to_keep);

SELECT '✅ 삭제 완료!' AS status;
*/

-- COMMIT;
ROLLBACK;

SELECT '⚠️ 현재는 ROLLBACK으로 설정되어 있습니다. 실제 삭제를 원하면 위 주석을 해제하세요.' AS warning;

END;


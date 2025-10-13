-- ========================================
-- 테스트 데이터 정리 (사업자 계정 제외)
-- ========================================
-- 주의: 이 스크립트는 사업자(role = 'business') 계정을 제외한 모든 데이터를 삭제합니다.
-- 프로덕션 환경에서는 절대 실행하지 마세요!

BEGIN;

-- 1. 삭제할 일반 사용자 ID 목록 확인 (사업자 제외)
SELECT 
    '🔍 삭제될 사용자 목록:' AS status,
    id, 
    name, 
    email, 
    role,
    businessstatus
FROM users 
WHERE role != 'business' OR role IS NULL
ORDER BY created_at DESC;

-- 2. 커뮤니티 댓글 삭제 (authorid 사용)
DELETE FROM community_comments
WHERE authorid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 커뮤니티 댓글 삭제 완료' AS status;

-- 3. 커뮤니티 게시글 삭제 (authorid 사용)
DELETE FROM community_posts
WHERE authorid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 커뮤니티 게시글 삭제 완료' AS status;

-- 4. 마켓플레이스 리스팅 삭제 (posted_by, claimed_by 사용)
DELETE FROM marketplace_listings
WHERE posted_by IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR claimed_by IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 마켓플레이스 리스팅 삭제 완료' AS status;

-- 5. 알림 삭제
DELETE FROM notifications
WHERE userid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 알림 삭제 완료' AS status;

-- 6. 채팅방 삭제 (chat_rooms 먼저 삭제, CASCADE로 messages도 삭제)
DELETE FROM chat_rooms
WHERE customerid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR businessid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 채팅방 삭제 완료' AS status;

-- 7. 메시지 삭제 (messages 테이블, senderid만 사용)
DELETE FROM messages
WHERE senderid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 발신자 기준 메시지 삭제 완료' AS status;

-- 8. 견적 삭제 (estimates 테이블, snake_case 컬럼명)
DELETE FROM estimates
WHERE customerid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR businessid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 견적 삭제 완료' AS status;

-- 9. 일자리/작업 삭제 (owner_business_id, assigned_business_id, transfer_to_business_id 사용)
DELETE FROM jobs
WHERE owner_business_id IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR assigned_business_id IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR transfer_to_business_id IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 일자리/작업 삭제 완료' AS status;

-- 10. 주문 삭제 (orders 테이블, camelCase 컬럼명)
DELETE FROM orders
WHERE "customerId" IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
) OR "businessId" IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 주문 삭제 완료' AS status;

-- 11. 프로필 미디어 삭제 (profile_media 테이블이 있다면)
DELETE FROM profile_media
WHERE userid IN (
    SELECT id FROM users WHERE role != 'business' OR role IS NULL
);
SELECT '✅ 프로필 미디어 삭제 완료' AS status;

-- 12. 일반 사용자 계정 삭제 (사업자 제외)
DELETE FROM users 
WHERE role != 'business' OR role IS NULL;
SELECT '✅ 일반 사용자 계정 삭제 완료' AS status;

-- 13. 남은 사업자 계정 확인
SELECT 
    '🎉 삭제 완료! 남은 사업자 계정:' AS status,
    COUNT(*) AS business_count
FROM users 
WHERE role = 'business';

SELECT 
    id,
    name,
    email,
    role,
    businessstatus,
    businessname
FROM users 
WHERE role = 'business'
ORDER BY created_at DESC;

-- ⚠️ 문제가 없다면 COMMIT, 문제가 있다면 ROLLBACK을 실행하세요
-- COMMIT;
-- ROLLBACK;

SELECT '⚠️ 트랜잭션이 아직 열려있습니다. COMMIT 또는 ROLLBACK을 실행하세요.' AS warning;

END;


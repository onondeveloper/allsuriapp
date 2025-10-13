-- ========================================
-- 테스트 데이터 자동 정리 (사업자 계정 제외)
-- ========================================
-- ⚠️ 이 스크립트는 자동으로 COMMIT됩니다!
-- 실행 전에 반드시 백업하세요!

BEGIN;

-- 삭제될 데이터 개수 확인
SELECT 
    '🔍 삭제 예정 데이터 요약' AS status,
    (SELECT COUNT(*) FROM users WHERE role != 'business' OR role IS NULL) AS "일반 사용자",
    (SELECT COUNT(*) FROM jobs) AS "작업/견적",
    (SELECT COUNT(*) FROM notifications) AS "알림",
    (SELECT COUNT(*) FROM community_posts) AS "커뮤니티 게시글",
    (SELECT COUNT(*) FROM community_comments) AS "커뮤니티 댓글";

-- 순차적 삭제 (외래 키 제약 고려, 실제 컬럼명 사용)
-- 1. Community (authorid 사용)
DELETE FROM community_comments WHERE authorid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);
DELETE FROM community_posts WHERE authorid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);

-- 2. Marketplace (posted_by, claimed_by 사용)
DELETE FROM marketplace_listings 
WHERE posted_by IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL) 
   OR claimed_by IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);

-- 3. Notifications (userid 사용)
DELETE FROM notifications WHERE userid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);

-- 4. Jobs (owner_business_id, assigned_business_id, transfer_to_business_id 사용)
DELETE FROM jobs 
WHERE owner_business_id IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL)
   OR assigned_business_id IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL)
   OR transfer_to_business_id IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);

-- 5. 기타 테이블 (존재하는 경우에만 삭제, 에러 무시)
DO $$
BEGIN
    -- Chat rooms (먼저 삭제하면 CASCADE로 messages도 삭제됨)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_rooms') THEN
            DELETE FROM chat_rooms 
            WHERE customerid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL) 
               OR businessid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'chat_rooms 삭제 중 에러 (무시됨): %', SQLERRM;
    END;
    
    -- Messages (roomid로 연결)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
            DELETE FROM messages 
            WHERE senderid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'messages 삭제 중 에러 (무시됨): %', SQLERRM;
    END;
    
    -- Estimates (여러 컬럼명 패턴 시도)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'estimates') THEN
            -- snake_case 시도
            DELETE FROM estimates 
            WHERE customerid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL) 
               OR businessid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'estimates 삭제 중 에러 (무시됨): %', SQLERRM;
    END;
    
    -- Orders (모든 주문 삭제, 사업자 계정 제외)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
            -- 방법 1: 사업자가 생성한 orders만 제외하고 모두 삭제
            -- orders 테이블이 users와 직접 연결되지 않을 수 있으므로, 모든 orders 삭제
            DELETE FROM orders;
            RAISE NOTICE '✅ 모든 주문 삭제 완료';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'orders 삭제 중 에러 (무시됨): %', SQLERRM;
    END;
    
    -- Profile media
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profile_media') THEN
            DELETE FROM profile_media WHERE userid IN (SELECT id FROM users WHERE role != 'business' OR role IS NULL);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'profile_media 삭제 중 에러 (무시됨): %', SQLERRM;
    END;
END $$;

-- 6. 마지막으로 사용자 삭제 (사업자 제외)
DELETE FROM users WHERE role != 'business' OR role IS NULL;

-- 결과 확인
SELECT 
    '✅ 삭제 완료!' AS status,
    (SELECT COUNT(*) FROM users WHERE role = 'business') AS "남은 사업자 수",
    (SELECT COUNT(*) FROM users) AS "총 사용자 수";

SELECT 
    '📋 남은 사업자 목록:' AS info,
    id,
    name,
    email,
    businessname,
    businessstatus
FROM users 
WHERE role = 'business'
ORDER BY created_at DESC;

COMMIT;

SELECT '🎉 모든 테스트 데이터가 삭제되었습니다!' AS result;


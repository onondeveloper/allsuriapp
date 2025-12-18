-- ============================================
-- 알림 시스템 진단 쿼리
-- ============================================

-- 1. 최근 알림 확인 (모든 사용자)
SELECT 
    id,
    userid,
    title,
    body,
    type,
    isread,
    createdat,
    orderid,
    jobid,
    chatroom_id
FROM notifications
ORDER BY createdat DESC
LIMIT 20;

-- 2. new_bid 타입 알림만 확인
SELECT 
    id,
    userid,
    title,
    body,
    type,
    createdat,
    orderid
FROM notifications
WHERE type = 'new_bid'
ORDER BY createdat DESC
LIMIT 10;

-- 3. 사용자별 FCM 토큰 확인
SELECT 
    id,
    name,
    businessname,
    role,
    fcm_token IS NOT NULL as has_fcm_token,
    LEFT(fcm_token, 30) as token_preview
FROM users
WHERE role = 'business'
ORDER BY createdat DESC
LIMIT 5;

-- 4. RLS 정책 확인
SELECT
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;

-- 5. 테스트: 현재 사용자 확인
SELECT auth.uid() as current_user_id;

-- 6. 테스트: 알림 삽입 (현재 사용자에게)
-- INSERT INTO notifications (userid, title, body, type, isread)
-- VALUES (auth.uid(), '테스트 알림', '이것은 테스트입니다', 'test', false);


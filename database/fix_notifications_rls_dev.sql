-- ============================================
-- 알림 RLS 정책 개발용 (모든 인증 사용자 허용)
-- ============================================

-- 1. 모든 기존 정책 완전 삭제
DROP POLICY IF EXISTS "authenticated_insert" ON notifications;
DROP POLICY IF EXISTS "own_select" ON notifications;
DROP POLICY IF EXISTS "own_update" ON notifications;
DROP POLICY IF EXISTS "own_delete" ON notifications;
DROP POLICY IF EXISTS "allow_all_authenticated_insert" ON notifications;
DROP POLICY IF EXISTS "allow_own_select" ON notifications;
DROP POLICY IF EXISTS "allow_own_update" ON notifications;
DROP POLICY IF EXISTS "allow_own_delete" ON notifications;
DROP POLICY IF EXISTS "dev_all_access" ON notifications;

-- 2. RLS 활성화 확인
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 3. 개발용 정책 생성 (모든 인증 사용자 허용)
CREATE POLICY "dev_all_access"
ON notifications
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- ✅ 정책 확인
-- ============================================
SELECT
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;

-- ============================================
-- 📝 테스트용 쿼리 (앱에서 실행 후)
-- ============================================
-- SELECT id, userid, title, type, createdat 
-- FROM notifications 
-- WHERE type IN ('new_bid', 'chat_message')
-- ORDER BY createdat DESC 
-- LIMIT 10;



-- ============================================
-- 간단한 RLS 정책 (개발용 - 모든 인증 사용자 허용)
-- ============================================

-- 모든 기존 정책 삭제
DROP POLICY IF EXISTS "prod_insert" ON notifications;
DROP POLICY IF EXISTS "prod_select" ON notifications;
DROP POLICY IF EXISTS "prod_update" ON notifications;
DROP POLICY IF EXISTS "prod_delete" ON notifications;
DROP POLICY IF EXISTS "dev_all_access" ON notifications;
DROP POLICY IF EXISTS "authenticated_all_access" ON notifications;

-- RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 개발용: 모든 인증 사용자 허용
CREATE POLICY "dev_all_access"
ON notifications
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 정책 확인
SELECT policyname, cmd, permissive, roles
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;

-- ============================================
-- 테스트: 최근 알림 확인
-- ============================================
SELECT 
    id,
    userid,
    title,
    body,
    type,
    createdat
FROM notifications
ORDER BY createdat DESC
LIMIT 10;


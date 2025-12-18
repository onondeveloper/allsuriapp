-- ============================================
-- 알림 RLS 정책 프로덕션용 (보안 강화)
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
DROP POLICY IF EXISTS "authenticated_all_access" ON notifications;

-- 2. RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 3. INSERT 정책: 모든 인증 사용자가 알림 생성 가능
CREATE POLICY "prod_insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 4. SELECT 정책: 자신의 알림만 조회 가능
CREATE POLICY "prod_select"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid());

-- 5. UPDATE 정책: 자신의 알림만 수정 가능
CREATE POLICY "prod_update"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid())
WITH CHECK (userid = auth.uid());

-- 6. DELETE 정책: 자신의 알림만 삭제 가능
CREATE POLICY "prod_delete"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid());

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

-- 예상 결과:
-- policyname   | cmd    | permissive  | roles
-- -------------|--------|-------------|------------------
-- prod_delete  | DELETE | PERMISSIVE  | {authenticated}
-- prod_insert  | INSERT | PERMISSIVE  | {authenticated}
-- prod_select  | SELECT | PERMISSIVE  | {authenticated}
-- prod_update  | UPDATE | PERMISSIVE  | {authenticated}

-- ============================================
-- 🧪 테스트용 쿼리 (앱에서 실행 후)
-- ============================================
-- SELECT id, userid, title, type, createdat 
-- FROM notifications 
-- WHERE userid = auth.uid()
-- ORDER BY createdat DESC 
-- LIMIT 10;


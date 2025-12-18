-- ============================================
-- 최종 수정: 알림 RLS + 필수 컬럼 확인
-- ============================================

-- 1. notifications 테이블에 필요한 컬럼 확인 및 추가
DO $$ 
BEGIN
    -- orderid 컬럼이 없으면 추가
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'orderid'
    ) THEN
        ALTER TABLE notifications ADD COLUMN orderid TEXT;
        RAISE NOTICE '✅ orderid 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'ℹ️ orderid 컬럼이 이미 존재합니다';
    END IF;

    -- chatroom_id 컬럼이 없으면 추가
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'chatroom_id'
    ) THEN
        ALTER TABLE notifications ADD COLUMN chatroom_id TEXT;
        RAISE NOTICE '✅ chatroom_id 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'ℹ️ chatroom_id 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 2. 모든 기존 RLS 정책 삭제
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
DROP POLICY IF EXISTS "prod_insert" ON notifications;
DROP POLICY IF EXISTS "prod_select" ON notifications;
DROP POLICY IF EXISTS "prod_update" ON notifications;
DROP POLICY IF EXISTS "prod_delete" ON notifications;

-- 3. RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 4. 프로덕션용 RLS 정책 생성
-- INSERT: 모든 인증 사용자가 알림 생성 가능
CREATE POLICY "prod_insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- SELECT: 자신의 알림만 조회 가능
CREATE POLICY "prod_select"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid());

-- UPDATE: 자신의 알림만 수정 가능
CREATE POLICY "prod_update"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid())
WITH CHECK (userid = auth.uid());

-- DELETE: 자신의 알림만 삭제 가능
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

-- ============================================
-- 📊 테스트 쿼리
-- ============================================
-- 현재 사용자의 알림 확인
-- SELECT id, userid, title, type, createdat 
-- FROM notifications 
-- WHERE userid = auth.uid()
-- ORDER BY createdat DESC 
-- LIMIT 10;


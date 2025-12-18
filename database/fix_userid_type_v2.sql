-- ============================================
-- STEP 1: userid 컬럼 타입 확인
-- ============================================

-- 1. notifications 테이블의 userid 컬럼 타입 확인
SELECT 
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'notifications' 
  AND column_name = 'userid';

-- 2. 샘플 데이터로 실제 타입 확인
SELECT 
    id,
    userid,
    pg_typeof(userid) as userid_actual_type,
    title,
    type
FROM notifications
ORDER BY createdat DESC
LIMIT 3;

-- ============================================
-- ⚠️ 위 결과를 확인한 후 아래 중 하나를 선택하세요!
-- ============================================

-- ============================================
-- OPTION 1: userid가 UUID 타입인 경우
-- ============================================
/*
-- 모든 기존 정책 삭제
DROP POLICY IF EXISTS "prod_insert" ON notifications;
DROP POLICY IF EXISTS "prod_select" ON notifications;
DROP POLICY IF EXISTS "prod_update" ON notifications;
DROP POLICY IF EXISTS "prod_delete" ON notifications;
DROP POLICY IF EXISTS "dev_all_access" ON notifications;

-- RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- INSERT: 모든 인증 사용자
CREATE POLICY "prod_insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- SELECT: 자신의 알림만 (UUID 비교)
CREATE POLICY "prod_select"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid());

-- UPDATE: 자신의 알림만 (UUID 비교)
CREATE POLICY "prod_update"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid())
WITH CHECK (userid = auth.uid());

-- DELETE: 자신의 알림만 (UUID 비교)
CREATE POLICY "prod_delete"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid());
*/

-- ============================================
-- OPTION 2: userid가 TEXT 타입인 경우
-- ============================================
/*
-- 모든 기존 정책 삭제
DROP POLICY IF EXISTS "prod_insert" ON notifications;
DROP POLICY IF EXISTS "prod_select" ON notifications;
DROP POLICY IF EXISTS "prod_update" ON notifications;
DROP POLICY IF EXISTS "prod_delete" ON notifications;
DROP POLICY IF EXISTS "dev_all_access" ON notifications;

-- RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- INSERT: 모든 인증 사용자
CREATE POLICY "prod_insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- SELECT: 자신의 알림만 (TEXT를 UUID로 캐스팅)
CREATE POLICY "prod_select"
ON notifications
FOR SELECT
TO authenticated
USING (userid::uuid = auth.uid());

-- UPDATE: 자신의 알림만 (TEXT를 UUID로 캐스팅)
CREATE POLICY "prod_update"
ON notifications
FOR UPDATE
TO authenticated
USING (userid::uuid = auth.uid())
WITH CHECK (userid::uuid = auth.uid());

-- DELETE: 자신의 알림만 (TEXT를 UUID로 캐스팅)
CREATE POLICY "prod_delete"
ON notifications
FOR DELETE
TO authenticated
USING (userid::uuid = auth.uid());
*/

-- ============================================
-- 정책 확인
-- ============================================
-- SELECT policyname, cmd, permissive, roles
-- FROM pg_policies
-- WHERE tablename = 'notifications'
-- ORDER BY policyname;


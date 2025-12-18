-- ============================================
-- 알림 RLS 정책 최종 수정
-- ============================================
-- 타입 캐스팅 이슈 해결: auth.uid()::text
-- DO $$ 블록 제거하여 호환성 향상
-- ============================================

-- 1. RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 2. 모든 기존 정책 삭제
DROP POLICY IF EXISTS "Enable insert for all authenticated users" ON notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON notifications;
DROP POLICY IF EXISTS "Allow all inserts" ON notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "Allow authenticated insert" ON notifications;

-- 3. INSERT 정책 생성
-- 모든 인증된 사용자가 알림을 생성할 수 있음
CREATE POLICY "Allow authenticated insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 4. SELECT 정책 생성
-- 사용자는 자신의 알림만 조회 가능
CREATE POLICY "Users can view their own notifications"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid()::text);

-- 5. UPDATE 정책 생성
-- 사용자는 자신의 알림만 수정 가능 (읽음 처리 등)
CREATE POLICY "Users can update their own notifications"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid()::text)
WITH CHECK (userid = auth.uid()::text);

-- 6. DELETE 정책 생성
-- 사용자는 자신의 알림만 삭제 가능
CREATE POLICY "Users can delete their own notifications"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid()::text);

-- ============================================
-- ✅ 완료!
-- ============================================


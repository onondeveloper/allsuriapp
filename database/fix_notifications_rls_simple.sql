-- ============================================
-- 알림 RLS 정책 수정 (간단 버전)
-- ============================================
-- 타입 불일치 에러 해결: auth.uid()::text 캐스팅 추가
-- ============================================

-- 1. RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 2. 기존 정책 모두 삭제
DROP POLICY IF EXISTS "Enable insert for all authenticated users" ON notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON notifications;
DROP POLICY IF EXISTS "Allow all inserts" ON notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

-- 3. INSERT 정책 (모든 인증된 사용자가 알림 생성 가능)
CREATE POLICY "Enable insert for all authenticated users"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 4. SELECT 정책 (자신의 알림만 조회)
CREATE POLICY "Users can view their own notifications"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid()::text);

-- 5. UPDATE 정책 (자신의 알림만 수정 - 읽음 처리)
CREATE POLICY "Users can update their own notifications"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid()::text)
WITH CHECK (userid = auth.uid()::text);

-- 6. DELETE 정책 (자신의 알림만 삭제)
CREATE POLICY "Users can delete their own notifications"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid()::text);

-- ============================================
-- ✅ 완료!
-- ============================================
-- 
-- 이제 알림이 정상적으로 저장되고 조회됩니다.
-- 
-- 테스트:
-- 1. 앱 재시작
-- 2. 채팅 메시지 전송 -> 알림 확인
-- 3. 입찰 -> 알림 확인
-- 
-- ============================================


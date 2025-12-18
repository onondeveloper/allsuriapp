-- ============================================
-- 알림 시스템 수정 (RLS 정책)
-- ============================================
-- 
-- 문제: notifications 테이블의 RLS 정책으로 인해 알림이 저장되지 않음
-- 해결: INSERT 권한 정책 추가
--
-- Supabase Dashboard > SQL Editor에서 실행하세요.
--
-- ============================================

-- 1. 기존 정책 확인
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'notifications';

-- ============================================
-- 2. INSERT 정책 추가/수정
-- ============================================

-- 2-1. 기존 INSERT 정책이 있다면 삭제
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON notifications;
DROP POLICY IF EXISTS "Allow all inserts" ON notifications;

-- 2-2. 새로운 INSERT 정책 생성 (모든 인증된 사용자가 알림 생성 가능)
CREATE POLICY "Enable insert for all authenticated users"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 참고: 보안을 더 강화하려면 아래처럼 수정 가능
-- WITH CHECK (userid = auth.uid()::text OR auth.uid() IS NOT NULL);

-- ============================================
-- 3. SELECT 정책 확인/추가
-- ============================================

-- 3-1. 기존 SELECT 정책 확인
-- SELECT * FROM pg_policies WHERE tablename = 'notifications' AND cmd = 'SELECT';

-- 3-2. SELECT 정책이 없다면 추가
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' 
        AND cmd = 'SELECT'
    ) THEN
        CREATE POLICY "Users can view their own notifications"
        ON notifications
        FOR SELECT
        TO authenticated
        USING (userid = auth.uid()::text);
    END IF;
END $$;

-- ============================================
-- 4. UPDATE 정책 확인/추가 (알림 읽음 처리)
-- ============================================

-- 4-1. 기존 UPDATE 정책 삭제
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;

-- 4-2. 새로운 UPDATE 정책 생성
CREATE POLICY "Users can update their own notifications"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid()::text)
WITH CHECK (userid = auth.uid()::text);

-- ============================================
-- 5. DELETE 정책 확인/추가
-- ============================================

-- 5-1. 기존 DELETE 정책 삭제
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

-- 5-2. 새로운 DELETE 정책 생성
CREATE POLICY "Users can delete their own notifications"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid()::text);

-- ============================================
-- 6. RLS 활성화 확인
-- ============================================

-- RLS가 활성화되어 있는지 확인
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'notifications';

-- RLS 활성화 (이미 활성화되어 있을 수 있음)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. 정책 적용 확인
-- ============================================

-- 최종 정책 목록 확인
SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN cmd = 'INSERT' THEN 'WITH CHECK: ' || COALESCE(with_check::text, 'N/A')
        WHEN cmd = 'SELECT' THEN 'USING: ' || COALESCE(qual::text, 'N/A')
        WHEN cmd = 'UPDATE' THEN 'USING: ' || COALESCE(qual::text, 'N/A') || ' | WITH CHECK: ' || COALESCE(with_check::text, 'N/A')
        WHEN cmd = 'DELETE' THEN 'USING: ' || COALESCE(qual::text, 'N/A')
    END as policy_detail
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY cmd, policyname;

-- ============================================
-- ✅ 완료!
-- ============================================
-- 
-- 이제 알림이 정상적으로 저장되고 조회됩니다.
-- 
-- 테스트 방법:
-- 1. 앱을 재시작
-- 2. 채팅 메시지 전송 -> 알림 확인
-- 3. 입찰자 선택 (낙찰) -> 알림 확인
-- 
-- ============================================

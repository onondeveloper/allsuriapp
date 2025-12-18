-- ============================================
-- 알림 RLS 정책 수정 (userid가 UUID 타입인 경우)
-- ============================================

-- 1. RLS 비활성화 (기존 정책 삭제를 위해)
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 2. 모든 기존 정책 강제 삭제
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'notifications') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON notifications';
    END LOOP;
END $$;

-- 3. RLS 다시 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 4. INSERT 정책 생성
CREATE POLICY "Allow authenticated insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 5. SELECT 정책 생성 (userid가 UUID 타입)
CREATE POLICY "Users can view their own notifications"
ON notifications
FOR SELECT
TO authenticated
USING (userid = auth.uid());

-- 6. UPDATE 정책 생성 (userid가 UUID 타입)
CREATE POLICY "Users can update their own notifications"
ON notifications
FOR UPDATE
TO authenticated
USING (userid = auth.uid())
WITH CHECK (userid = auth.uid());

-- 7. DELETE 정책 생성 (userid가 UUID 타입)
CREATE POLICY "Users can delete their own notifications"
ON notifications
FOR DELETE
TO authenticated
USING (userid = auth.uid());

-- ============================================
-- ✅ 완료!
-- ============================================


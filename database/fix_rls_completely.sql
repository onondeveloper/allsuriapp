-- ============================================
-- RLS 정책 완전 재설정 (강력 버전)
-- ============================================

-- 1️⃣ order_bids 테이블 RLS 완전 비활성화 후 재설정
ALTER TABLE order_bids DISABLE ROW LEVEL SECURITY;

-- 모든 정책 삭제 (CASCADE로 강제 삭제)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'order_bids') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON order_bids CASCADE', r.policyname);
    END LOOP;
END $$;

-- RLS 다시 활성화
ALTER TABLE order_bids ENABLE ROW LEVEL SECURITY;

-- 단순한 정책 생성
CREATE POLICY "allow_all_authenticated" ON order_bids
    FOR ALL TO authenticated
    USING (true)
    WITH CHECK (true);

-- 2️⃣ notifications 테이블 RLS 완전 재설정
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 모든 정책 삭제
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'notifications') LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON notifications CASCADE', r.policyname);
    END LOOP;
END $$;

-- RLS 다시 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 단순한 정책 생성
CREATE POLICY "allow_all_authenticated" ON notifications
    FOR ALL TO authenticated
    USING (true)
    WITH CHECK (true);

-- 3️⃣ 결과 확인
SELECT 'order_bids 정책:' as info;
SELECT policyname, cmd, permissive
FROM pg_policies
WHERE tablename = 'order_bids';

SELECT 'notifications 정책:' as info;
SELECT policyname, cmd, permissive
FROM pg_policies
WHERE tablename = 'notifications';


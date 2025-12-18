-- ============================================
-- order_bids와 notifications RLS 정책 수정
-- ============================================

-- 1️⃣ order_bids RLS 활성화 및 정책 설정
ALTER TABLE order_bids ENABLE ROW LEVEL SECURITY;

-- 기존 정책 모두 삭제
DROP POLICY IF EXISTS order_bids_select_policy ON order_bids;
DROP POLICY IF EXISTS order_bids_insert_policy ON order_bids;
DROP POLICY IF EXISTS order_bids_update_policy ON order_bids;
DROP POLICY IF EXISTS order_bids_delete_policy ON order_bids;

-- 새 정책 생성 (모든 인증된 사용자가 접근 가능)
CREATE POLICY order_bids_select_policy ON order_bids
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY order_bids_insert_policy ON order_bids
    FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY order_bids_update_policy ON order_bids
    FOR UPDATE TO authenticated
    USING (true);

CREATE POLICY order_bids_delete_policy ON order_bids
    FOR DELETE TO authenticated
    USING (true);

-- 2️⃣ notifications RLS 활성화 및 정책 설정
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 기존 정책 모두 삭제
DROP POLICY IF EXISTS prod_select ON notifications;
DROP POLICY IF EXISTS prod_insert ON notifications;
DROP POLICY IF EXISTS prod_update ON notifications;
DROP POLICY IF EXISTS prod_delete ON notifications;

-- 새 정책 생성
-- INSERT: 모든 인증된 사용자가 알림 생성 가능
CREATE POLICY prod_insert ON notifications
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- SELECT: 자신의 알림만 조회 가능
CREATE POLICY prod_select ON notifications
    FOR SELECT TO authenticated
    USING (userid = auth.uid());

-- UPDATE: 자신의 알림만 수정 가능
CREATE POLICY prod_update ON notifications
    FOR UPDATE TO authenticated
    USING (userid = auth.uid());

-- DELETE: 자신의 알림만 삭제 가능
CREATE POLICY prod_delete ON notifications
    FOR DELETE TO authenticated
    USING (userid = auth.uid());

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE '✅ order_bids와 notifications RLS 정책 재설정 완료!';
    RAISE NOTICE '   order_bids: 모든 인증된 사용자가 접근 가능';
    RAISE NOTICE '   notifications: INSERT는 누구나, SELECT/UPDATE/DELETE는 본인만';
END $$;


DROP POLICY IF EXISTS "dev_all_access" ON notifications;

-- INSERT: 모든 인증 사용자
CREATE POLICY "prod_insert" ON notifications FOR INSERT TO authenticated WITH CHECK (true);

-- SELECT: 자신의 알림만
CREATE POLICY "prod_select" ON notifications FOR SELECT TO authenticated USING (userid::text = auth.uid()::text);

-- UPDATE: 자신의 알림만
CREATE POLICY "prod_update" ON notifications FOR UPDATE TO authenticated USING (userid::text = auth.uid()::text) WITH CHECK (userid::text = auth.uid()::text);

-- DELETE: 자신의 알림만
CREATE POLICY "prod_delete" ON notifications FOR DELETE TO authenticated USING (userid::text = auth.uid()::text);
-- ============================================
-- 🚨 RLS 완전 비활성화 (임시 해결책)
-- ============================================
-- 
-- ⚠️ 주의: 이는 임시 해결책입니다.
-- 프로덕션 환경에서는 적절한 인증 및 RLS 정책을 사용해야 합니다.
-- 
-- 이 스크립트는 order_bids와 notifications 테이블의 RLS를
-- 완전히 비활성화하여 모든 사용자가 접근할 수 있게 합니다.
-- ============================================

-- 1️⃣ order_bids 테이블 RLS 비활성화
ALTER TABLE order_bids DISABLE ROW LEVEL SECURITY;

-- 2️⃣ notifications 테이블 RLS 비활성화
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 3️⃣ 확인
SELECT 
    schemaname,
    tablename,
    rowsecurity as "RLS 활성화 여부"
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename IN ('order_bids', 'notifications')
ORDER BY tablename;

-- 4️⃣ 기존 정책 확인 (비활성화되었으므로 적용되지 않음)
SELECT 
    tablename,
    policyname,
    cmd,
    '⚠️ RLS가 비활성화되어 이 정책은 적용되지 않습니다' as status
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename IN ('order_bids', 'notifications')
ORDER BY tablename, cmd;

-- ✅ 완료!
SELECT 
    '✅ RLS 비활성화 완료!' as result,
    'order_bids와 notifications 테이블의 RLS가 비활성화되었습니다.' as message,
    '모든 사용자가 이 테이블에 접근할 수 있습니다.' as warning;



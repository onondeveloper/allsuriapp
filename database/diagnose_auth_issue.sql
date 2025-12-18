-- ============================================
-- 🔍 인증 및 RLS 문제 진단 SQL
-- ============================================

-- 1️⃣ 현재 auth.uid() 확인 (SQL Editor에서 실행 시 null)
SELECT 
    '현재 auth.uid()' as check_name,
    auth.uid() as current_uid,
    CASE 
        WHEN auth.uid() IS NULL THEN '⚠️ NULL (인증 필요)'
        ELSE '✅ 인증됨'
    END as status;

-- 2️⃣ 벤허 사용자의 입찰 데이터 확인 (RLS 무시)
SELECT 
    '벤허의 입찰 데이터' as check_name,
    COUNT(*) as total_bids,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_bids,
    COUNT(*) FILTER (WHERE status = 'selected') as selected_bids
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248';

-- 3️⃣ RLS 정책 확인
SELECT 
    tablename,
    policyname,
    permissive,
    cmd,
    qual as "정책 조건"
FROM pg_policies
WHERE schemaname = 'public' 
AND tablename = 'order_bids'
ORDER BY tablename, cmd;

-- 4️⃣ 앱이 사용하는 서비스 롤 확인
SELECT 
    '서비스 롤 테스트' as test_name,
    COUNT(*) as accessible_bids
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248';



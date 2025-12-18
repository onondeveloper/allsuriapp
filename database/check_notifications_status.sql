-- 알림 시스템 상태 확인 스크립트

-- 1. notifications 테이블의 RLS 상태 확인
SELECT 
    schemaname,
    tablename,
    rowsecurity 
FROM pg_tables 
WHERE tablename = 'notifications';

-- 2. notifications 테이블의 RLS 정책 확인
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

-- 3. 최근 알림 데이터 확인 (전체 - RLS 무시)
-- 주의: 이 쿼리는 Supabase SQL Editor에서 실행해야 합니다 (RLS 우회)
SELECT 
    id,
    userid,
    title,
    body,
    type,
    isread,
    createdat
FROM notifications
ORDER BY createdat DESC
LIMIT 20;

-- 4. 특정 사용자의 알림 개수 확인 (RLS 적용됨)
-- 사용자 ID를 실제 ID로 변경하세요
-- SELECT COUNT(*) as total_count
-- FROM notifications
-- WHERE userid = '7cdd586f-e527-46a8-a4a1-db9ed4812248';


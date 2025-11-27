-- ==========================================
-- Supabase Realtime 활성화
-- 오더 및 입찰 시스템에 대한 실시간 업데이트 설정
-- ==========================================

-- 1. marketplace_listings 테이블에 대한 Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;

-- 2. order_bids 테이블에 대한 Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;

-- 3. jobs 테이블에 대한 Realtime 활성화 (선택적)
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;

-- 4. 현재 Realtime이 활성화된 테이블 확인
SELECT 
  schemaname,
  tablename
FROM 
  pg_publication_tables
WHERE 
  pubname = 'supabase_realtime'
ORDER BY 
  tablename;

-- ==========================================
-- 설명:
-- - 이 스크립트를 Supabase SQL Editor에서 실행하세요
-- - Realtime이 활성화되면 클라이언트에서 실시간 구독이 가능합니다
-- - 테이블이 이미 추가되어 있으면 에러가 발생할 수 있지만 무시해도 됩니다
-- ==========================================


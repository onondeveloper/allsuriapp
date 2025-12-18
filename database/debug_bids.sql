-- ============================================
-- 입찰 카운트 디버그 쿼리
-- ============================================

-- 1. order_bids 테이블 구조 확인
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'order_bids'
ORDER BY ordinal_position;

-- 2. 특정 사용자의 입찰 목록 (status별)
-- ⚠️ [사용자 ID]를 실제 ID로 변경하세요
SELECT 
    id,
    bidder_id,
    listing_id,
    status,
    created_at
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
ORDER BY created_at DESC;

-- 3. status별 카운트
SELECT 
    status,
    COUNT(*) as count
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
GROUP BY status;

-- 4. pending 상태만 카운트
SELECT COUNT(*) as pending_count
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
  AND status = 'pending';


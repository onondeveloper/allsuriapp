-- order_bids 테이블에서 bid_amount 컬럼 확인
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'order_bids'
ORDER BY ordinal_position;

-- 특정 사용자의 입찰 금액 확인 (⚠️ ID 변경)
SELECT 
    id,
    bidder_id,
    listing_id,
    bid_amount,
    status,
    created_at
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
  AND status = 'selected'
ORDER BY created_at DESC
LIMIT 5;

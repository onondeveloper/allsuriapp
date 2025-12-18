-- 1️⃣ order_bids 테이블 컬럼 확인 (먼저 실행)
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'order_bids'
ORDER BY ordinal_position;

-- 2️⃣ 김포 화장실 공사 입찰 확인 (bid_amount 제외)
SELECT *
FROM order_bids
WHERE listing_id = 'b83a8059-6885-49da-b988-676c3f9c11e7'
  AND bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY created_at DESC;

-- 3️⃣ 벤허(7cdd586f)의 모든 입찰 확인
SELECT *
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY created_at DESC;

-- 4️⃣ RLS 정책 확인
SELECT 
    policyname,
    cmd,
    permissive
FROM pg_policies
WHERE tablename = 'notifications';


-- ============================================
-- 간단한 디버그 쿼리
-- ============================================

-- 1️⃣ jobs 테이블에 어떤 컬럼이 있는지 확인
SELECT column_name 
FROM information_schema.columns
WHERE table_name = 'jobs'
ORDER BY ordinal_position;

-- 2️⃣ 특정 사용자의 공사 5개만 확인 (⚠️ 사용자 ID 변경)
SELECT *
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
LIMIT 5;

-- 3️⃣ 완료된 공사의 금액 정보 확인 (⚠️ 사용자 ID 변경)
SELECT 
    id,
    awarded_amount,
    commission_rate,
    status
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
  AND status IN ('completed', 'awaiting_confirmation');

-- 4️⃣ 입찰 정보 확인 (⚠️ 사용자 ID 변경)
SELECT 
    id,
    bidder_id,
    status,
    created_at
FROM order_bids
WHERE bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY created_at DESC;


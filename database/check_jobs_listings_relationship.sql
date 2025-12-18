-- ============================================
-- 🔍 jobs와 marketplace_listings 관계 확인
-- ============================================

-- 1️⃣ jobs 테이블의 샘플 데이터 (벤허가 낙찰받은 공사)
SELECT 
    id,
    title,
    assigned_business_id,
    awarded_amount,
    budget_amount,
    status,
    created_at
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY created_at DESC
LIMIT 3;

-- 2️⃣ marketplace_listings 테이블 구조 확인
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'marketplace_listings'
ORDER BY ordinal_position;

-- 3️⃣ order_bids 테이블로 jobs와 marketplace_listings 연결 확인
SELECT 
    ob.id as bid_id,
    ob.listing_id,
    ob.job_id,
    ob.bidder_id,
    ob.status as bid_status,
    j.title as job_title,
    j.awarded_amount,
    j.budget_amount as job_budget,
    ml.title as listing_title,
    ml.budget_amount as listing_budget
FROM order_bids ob
LEFT JOIN jobs j ON ob.job_id = j.id
LEFT JOIN marketplace_listings ml ON ob.listing_id = ml.id
WHERE ob.bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
    AND ob.status = 'selected'
ORDER BY ob.created_at DESC
LIMIT 5;


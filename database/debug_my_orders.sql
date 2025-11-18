-- 현재 사용자의 오더 및 공사 데이터 확인
-- 사용자 ID: 7cdd586f-e527-46a8-a4a1-db9ed4812248

-- 1. 내가 생성한 marketplace_listings (내 오더 관리용)
SELECT 
  id,
  jobid,
  title,
  status,
  posted_by,
  claimed_by,
  selected_bidder_id,
  createdat
FROM marketplace_listings
WHERE posted_by = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY createdat DESC;

-- 2. 내가 소유하거나 할당받은 jobs (내 공사용)
SELECT 
  j.id as job_id,
  j.title,
  j.status,
  j.owner_business_id,
  j.assigned_business_id,
  ml.id as listing_id,
  ml.status as listing_status,
  ml.posted_by
FROM jobs j
LEFT JOIN marketplace_listings ml ON j.id = ml.jobid
WHERE j.owner_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR j.assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY j.created_at DESC;

-- 3. 내가 입찰한 오더 (order_bids)
SELECT 
  ob.id as bid_id,
  ob.listing_id,
  ob.status as bid_status,
  ml.title,
  ml.status as listing_status,
  ml.posted_by,
  ob.created_at
FROM order_bids ob
JOIN marketplace_listings ml ON ob.listing_id = ml.id
WHERE ob.bidder_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY ob.created_at DESC;

-- 4. 모든 marketplace_listings과 jobs 관계 확인
SELECT 
  ml.id as listing_id,
  ml.jobid,
  ml.title,
  ml.status as listing_status,
  ml.posted_by,
  ml.claimed_by,
  ml.selected_bidder_id,
  j.id as job_id,
  j.status as job_status,
  j.owner_business_id,
  j.assigned_business_id
FROM marketplace_listings ml
LEFT JOIN jobs j ON ml.jobid = j.id
WHERE ml.posted_by = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR j.owner_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR j.assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY ml.createdat DESC;


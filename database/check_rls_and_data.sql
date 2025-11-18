-- RLS 정책 및 실제 데이터 확인
-- 사용자 ID: 7cdd586f-e527-46a8-a4a1-db9ed4812248

-- 1. marketplace_listings 테이블의 실제 데이터 (RLS 무시)
SELECT 
  id,
  jobid,
  title,
  status,
  posted_by,
  claimed_by,
  selected_bidder_id,
  bid_count
FROM marketplace_listings
ORDER BY createdat DESC
LIMIT 10;

-- 2. jobs 테이블의 실제 데이터
SELECT 
  id as job_id,
  title,
  status,
  owner_business_id,
  assigned_business_id
FROM jobs
WHERE owner_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY created_at DESC
LIMIT 10;

-- 3. marketplace_listings RLS 정책 확인
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
WHERE tablename = 'marketplace_listings';

-- 4. jobs와 marketplace_listings 관계 확인
SELECT 
  j.id as job_id,
  j.title as job_title,
  j.status as job_status,
  j.owner_business_id,
  j.assigned_business_id,
  ml.id as listing_id,
  ml.title as listing_title,
  ml.status as listing_status,
  ml.posted_by,
  ml.jobid
FROM jobs j
LEFT JOIN marketplace_listings ml ON j.id = ml.jobid
WHERE j.owner_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR j.assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY j.created_at DESC
LIMIT 10;

-- 5. marketplace_listings에서 jobid가 NULL인 경우 확인
SELECT 
  id,
  title,
  status,
  posted_by,
  jobid
FROM marketplace_listings
WHERE jobid IS NULL
LIMIT 5;


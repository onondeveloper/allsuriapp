-- 특정 사용자 데이터 확인
-- Supabase SQL Editor에서 실행

-- 1. 사용자 7cdd586f의 알림 확인
SELECT 
  id,
  title,
  body,
  type,
  jobid,
  postid,
  isread,
  createdat
FROM notifications
WHERE userid = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY createdat DESC;

-- 2. 사용자 7cdd586f의 채팅방 확인
SELECT *
FROM chat_rooms
WHERE participant_a = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR participant_b = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR customerid = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR businessid = '7cdd586f-e527-46a8-a4a1-db9ed4812248';

-- 3. 사용자 7cdd586f가 받은(assigned) 공사 확인
SELECT 
  id,
  title,
  owner_business_id,
  assigned_business_id,
  status,
  created_at
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248';

-- 4. 해당 공사의 marketplace_listings 확인
SELECT 
  ml.id,
  ml.jobid,
  ml.title,
  ml.posted_by,
  ml.claimed_by,
  ml.status,
  j.id as job_id,
  j.assigned_business_id
FROM marketplace_listings ml
LEFT JOIN jobs j ON ml.jobid = j.id
WHERE j.assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248';

-- 5. jobId=d1d7ffc2... 공사 확인
SELECT *
FROM jobs
WHERE id = 'd1d7ffc2-2aa1-421a-9ae4-2264183b5a89';

-- 6. 해당 job의 marketplace_listings 확인
SELECT *
FROM marketplace_listings
WHERE jobid = 'd1d7ffc2-2aa1-421a-9ae4-2264183b5a89';


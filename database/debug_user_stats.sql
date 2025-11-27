-- ==========================================
-- 사용자 통계 디버깅
-- 입찰자 정보에 0으로 표시되는 문제 확인
-- ==========================================

-- 1. estimates 테이블 스키마 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'estimates'
  AND column_name LIKE '%business%'
ORDER BY column_name;

-- 2. jobs 테이블 스키마 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'jobs'
  AND column_name LIKE '%business%'
ORDER BY column_name;

-- 3. users 테이블에 통계 컬럼이 있는지 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name LIKE '%count%'
ORDER BY column_name;

-- 4. 실제 견적 데이터 확인
SELECT 
  u.businessname,
  u.id as user_id,
  COUNT(e.id) as actual_estimates
FROM users u
LEFT JOIN estimates e ON e.businessid = u.id
WHERE u.role = 'business'
GROUP BY u.id, u.businessname
ORDER BY actual_estimates DESC
LIMIT 10;

-- 5. 실제 완료된 공사 확인
SELECT 
  u.businessname,
  u.id as user_id,
  COUNT(j.id) as actual_completed_jobs
FROM users u
LEFT JOIN jobs j ON j.assigned_business_id = u.id
WHERE u.role = 'business'
  AND (j.status = 'completed' OR j.status IS NULL)
GROUP BY u.id, u.businessname
ORDER BY actual_completed_jobs DESC
LIMIT 10;

-- 6. users 테이블의 현재 통계 값 확인
SELECT 
  businessname,
  estimates_created_count,
  jobs_accepted_count
FROM users
WHERE role = 'business'
ORDER BY businessname
LIMIT 10;

-- 7. 특정 사업자의 상세 정보 (입찰자 화면에 보이는 사업자)
-- 에이레네 주식회사와 바른설비
SELECT 
  u.businessname,
  u.estimates_created_count,
  u.jobs_accepted_count,
  (SELECT COUNT(*) FROM estimates WHERE businessid = u.id) as actual_estimates,
  (SELECT COUNT(*) FROM jobs WHERE assigned_business_id = u.id AND status = 'completed') as actual_jobs
FROM users u
WHERE u.businessname IN ('에이레네 주식회사', '바른설비')
   OR u.name IN ('에이레네 주식회사', '바른설비');

-- 8. order_bids에서 입찰자 정보 확인
SELECT 
  ob.bidder_id,
  u.businessname,
  COUNT(ob.id) as bid_count
FROM order_bids ob
JOIN users u ON u.id = ob.bidder_id
GROUP BY ob.bidder_id, u.businessname
ORDER BY bid_count DESC
LIMIT 10;


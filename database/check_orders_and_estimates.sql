-- 오더와 견적 데이터 확인용 SQL
-- Supabase SQL Editor에서 실행

-- 1. 완료된 오더 확인 (marketplace_listings)
SELECT 
  id,
  title,
  budget_amount,
  status,
  claimed_by,
  claimed_at,
  createdat
FROM marketplace_listings
WHERE status = 'assigned' OR claimed_by IS NOT NULL
ORDER BY createdat DESC;

-- 2. 모든 견적 확인 (estimates) - 모든 컬럼 조회
SELECT *
FROM estimates
ORDER BY createdat DESC
LIMIT 10;

-- 3. 오더별 견적 존재 여부 확인
SELECT 
  ml.id as listing_id,
  ml.title,
  ml.budget_amount as order_budget,
  ml.status as order_status,
  ml.claimed_by,
  e.id as estimate_id,
  e.amount as estimate_amount,
  e.status as estimate_status
FROM marketplace_listings ml
LEFT JOIN jobs j ON ml.jobid = j.id
LEFT JOIN estimates e ON j.id::text = e."orderId"::text
WHERE ml.status = 'assigned' OR ml.claimed_by IS NOT NULL
ORDER BY ml.createdat DESC;

-- 4. 견적 상태별 개수와 금액 합계
SELECT 
  status,
  COUNT(*) as count,
  SUM(amount) as total_amount
FROM estimates
GROUP BY status;

-- 5. 오더 상태별 개수와 예산 합계
SELECT 
  status,
  COUNT(*) as count,
  SUM(budget_amount) as total_budget
FROM marketplace_listings
GROUP BY status;

-- 6. estimates 테이블 스키마 확인
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'estimates'
ORDER BY ordinal_position;

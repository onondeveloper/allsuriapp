-- ============================================
-- 매출 데이터 디버그 쿼리
-- ============================================

-- 1. jobs 테이블 컬럼 구조 확인
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'jobs'
ORDER BY ordinal_position;

-- 2. 특정 사용자의 완료된 공사 확인
-- ⚠️ [사용자 ID]를 실제 ID로 변경하세요
SELECT 
    id,
    assigned_business_id,
    awarded_amount,
    commission_rate,
    status,
    createdat
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
  AND status IN ('completed', 'awaiting_confirmation')
ORDER BY createdat DESC
LIMIT 20;

-- 3. 금액이 있는 공사만 필터링
SELECT 
    id,
    awarded_amount,
    commission_rate,
    status
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
  AND status IN ('completed', 'awaiting_confirmation')
  AND awarded_amount IS NOT NULL
  AND awarded_amount > 0
ORDER BY created_at DESC;

-- 4. 통계 확인
SELECT 
    COUNT(*) as total_jobs,
    COUNT(awarded_amount) as jobs_with_amount,
    SUM(awarded_amount) as total_amount,
    AVG(commission_rate) as avg_commission_rate
FROM jobs
WHERE assigned_business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'  -- ⚠️ 여기를 실제 ID로 변경
  AND status IN ('completed', 'awaiting_confirmation');


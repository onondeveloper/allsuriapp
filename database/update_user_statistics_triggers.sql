-- ==========================================
-- 사용자 통계 자동 업데이트 트리거
-- estimates_created_count, jobs_accepted_count 자동 계산
-- ==========================================

-- ==========================================
-- 1. estimates_created_count 업데이트 함수
-- ==========================================
CREATE OR REPLACE FUNCTION update_estimates_created_count()
RETURNS TRIGGER AS $$
BEGIN
  -- 견적 생성 시
  IF (TG_OP = 'INSERT') THEN
    UPDATE users
    SET estimates_created_count = COALESCE(estimates_created_count, 0) + 1
    WHERE id = NEW.businessid;
    RETURN NEW;
  END IF;
  
  -- 견적 삭제 시
  IF (TG_OP = 'DELETE') THEN
    UPDATE users
    SET estimates_created_count = GREATEST(0, COALESCE(estimates_created_count, 0) - 1)
    WHERE id = OLD.businessid;
    RETURN OLD;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_update_estimates_created_count ON estimates;
CREATE TRIGGER trigger_update_estimates_created_count
  AFTER INSERT OR DELETE ON estimates
  FOR EACH ROW
  EXECUTE FUNCTION update_estimates_created_count();

-- ==========================================
-- 2. jobs_accepted_count 업데이트 함수
-- ==========================================
CREATE OR REPLACE FUNCTION update_jobs_accepted_count()
RETURNS TRIGGER AS $$
BEGIN
  -- jobs 테이블에서 assigned_business_id 설정 시
  IF (TG_OP = 'INSERT' AND NEW.assigned_business_id IS NOT NULL) THEN
    UPDATE users
    SET jobs_accepted_count = COALESCE(jobs_accepted_count, 0) + 1
    WHERE id = NEW.assigned_business_id;
    RETURN NEW;
  END IF;
  
  -- jobs 테이블에서 assigned_business_id 변경 시
  IF (TG_OP = 'UPDATE' AND OLD.assigned_business_id IS NULL AND NEW.assigned_business_id IS NOT NULL) THEN
    UPDATE users
    SET jobs_accepted_count = COALESCE(jobs_accepted_count, 0) + 1
    WHERE id = NEW.assigned_business_id;
    RETURN NEW;
  END IF;
  
  -- jobs 테이블에서 assigned_business_id 제거 시
  IF (TG_OP = 'UPDATE' AND OLD.assigned_business_id IS NOT NULL AND NEW.assigned_business_id IS NULL) THEN
    UPDATE users
    SET jobs_accepted_count = GREATEST(0, COALESCE(jobs_accepted_count, 0) - 1)
    WHERE id = OLD.assigned_business_id;
    RETURN NEW;
  END IF;
  
  -- jobs 삭제 시
  IF (TG_OP = 'DELETE' AND OLD.assigned_business_id IS NOT NULL) THEN
    UPDATE users
    SET jobs_accepted_count = GREATEST(0, COALESCE(jobs_accepted_count, 0) - 1)
    WHERE id = OLD.assigned_business_id;
    RETURN OLD;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_update_jobs_accepted_count ON jobs;
CREATE TRIGGER trigger_update_jobs_accepted_count
  AFTER INSERT OR UPDATE OR DELETE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_jobs_accepted_count();

-- ==========================================
-- 3. 기존 데이터에 대한 통계 재계산
-- ==========================================

-- estimates_created_count 재계산
UPDATE users u
SET estimates_created_count = (
  SELECT COUNT(*)
  FROM estimates e
  WHERE e.businessid = u.id
)
WHERE u.role = 'business';

-- jobs_accepted_count 재계산
UPDATE users u
SET jobs_accepted_count = (
  SELECT COUNT(*)
  FROM jobs j
  WHERE j.assigned_business_id = u.id
)
WHERE u.role = 'business';

-- ==========================================
-- 4. 확인 쿼리
-- ==========================================
SELECT 
  id,
  businessname,
  estimates_created_count,
  jobs_accepted_count
FROM users
WHERE role = 'business'
  AND (estimates_created_count > 0 OR jobs_accepted_count > 0)
ORDER BY estimates_created_count DESC, jobs_accepted_count DESC
LIMIT 10;

SELECT '✅ 사용자 통계 트리거 설정 완료!' AS status;
SELECT '📊 위 목록에 통계가 제대로 표시되는지 확인하세요' AS note;



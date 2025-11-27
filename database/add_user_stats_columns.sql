-- ==========================================
-- 사용자 통계 컬럼 추가
-- 입찰자 정보에 "견적 올린 수", "완료 건 수" 표시를 위한 컬럼
-- ==========================================

-- 1. 컬럼 추가 (이미 있으면 무시됨)
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS estimates_created_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS jobs_accepted_count INTEGER DEFAULT 0;

-- 2. 기존 데이터 업데이트 (실제 값으로 채우기)
UPDATE public.users SET 
  estimates_created_count = (
    SELECT COUNT(*) 
    FROM estimates 
    WHERE businessid = users.id OR business_id = users.id
  ),
  jobs_accepted_count = (
    SELECT COUNT(*) 
    FROM jobs 
    WHERE (assigned_business_id = users.id OR assignedbusinessid = users.id)
      AND status = 'completed'
  )
WHERE role = 'business';

-- 3. 인덱스 추가 (성능 향상)
CREATE INDEX IF NOT EXISTS idx_estimates_businessid ON estimates(businessid);
CREATE INDEX IF NOT EXISTS idx_estimates_business_id ON estimates(business_id);
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_business ON jobs(assigned_business_id);

-- 4. 확인 쿼리
SELECT 
  id,
  businessname,
  estimates_created_count,
  jobs_accepted_count
FROM users
WHERE role = 'business'
  AND (estimates_created_count > 0 OR jobs_accepted_count > 0)
ORDER BY businessname
LIMIT 10;

-- 5. 자동 업데이트 트리거 (선택사항)
-- 견적 생성 시 카운트 자동 증가
CREATE OR REPLACE FUNCTION increment_estimates_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE users 
  SET estimates_created_count = estimates_created_count + 1
  WHERE id = NEW.businessid OR id = NEW.business_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_increment_estimates ON estimates;
CREATE TRIGGER trigger_increment_estimates
  AFTER INSERT ON estimates
  FOR EACH ROW
  EXECUTE FUNCTION increment_estimates_count();

-- 공사 완료 시 카운트 자동 증가
CREATE OR REPLACE FUNCTION increment_jobs_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE users 
    SET jobs_accepted_count = jobs_accepted_count + 1
    WHERE id = NEW.assigned_business_id OR id = NEW.assignedbusinessid;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_increment_jobs ON jobs;
CREATE TRIGGER trigger_increment_jobs
  AFTER UPDATE ON jobs
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION increment_jobs_count();

SELECT '✅ 사용자 통계 컬럼 및 트리거 설정 완료!' as status;


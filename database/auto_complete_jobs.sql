-- ==========================================
-- 🔧 14일 경과 시 공사 자동 완료 처리 SQL
-- ==========================================

-- 1. 자동 완료 처리를 위한 함수 생성
CREATE OR REPLACE FUNCTION public.auto_complete_old_assigned_jobs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- 높은 권한으로 실행 (RLS 무시)
AS $$
DECLARE
  v_count_jobs integer;
  v_count_listings integer;
BEGIN
  -- A. 14일 이상 경과한 'assigned' 또는 'in_progress' 상태의 공사들 업데이트
  -- 'assigned' 상태가 된 지 14일이 지난 건들을 찾음
  
  -- 1. jobs 테이블 업데이트
  UPDATE public.jobs
  SET 
    status = 'completed',
    updated_at = NOW()
  WHERE 
    status IN ('assigned', 'in_progress', 'awaiting_confirmation')
    AND updated_at < NOW() - INTERVAL '14 days';
    
  GET DIAGNOSTICS v_count_jobs = ROW_COUNT;

  -- 2. marketplace_listings 테이블 업데이트 (동기화)
  UPDATE public.marketplace_listings
  SET 
    status = 'completed',
    updatedat = NOW()
  WHERE 
    status IN ('assigned', 'awaiting_confirmation')
    AND updatedat < NOW() - INTERVAL '14 days';

  GET DIAGNOSTICS v_count_listings = ROW_COUNT;

  RAISE NOTICE 'Auto-completed % jobs and % marketplace listings.', v_count_jobs, v_count_listings;
END;
$$;

-- 2. (선택 사항) Supabase pg_cron이 활성화되어 있다면 매일 실행되도록 예약
-- SQL Editor에서 실행 전 pg_cron 확장 기능이 활성화되어 있는지 확인 필요
-- SELECT cron.schedule('daily-auto-complete-jobs', '0 0 * * *', 'SELECT public.auto_complete_old_assigned_jobs()');

-- 3. 즉시 실행 테스트용
-- SELECT public.auto_complete_old_assigned_jobs();

SELECT '✅ 자동 완료 처리 함수(auto_complete_old_assigned_jobs) 생성 완료' AS result;

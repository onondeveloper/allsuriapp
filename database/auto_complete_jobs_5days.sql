-- ============================================================
-- PART A: 자동 완료 함수 생성 (pg_cron 없이 실행 가능)
-- ============================================================
-- SQL Editor에서 PART A 먼저 실행하세요.
-- pg_cron 활성화 후 PART B를 실행하세요.
-- ============================================================

CREATE OR REPLACE FUNCTION public.auto_complete_jobs_after_5days()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count_jobs      integer;
  v_count_listings  integer;
BEGIN
  -- jobs: 생성된 지 5일 경과 + 미완료 상태인 공사 자동 완료
  UPDATE public.jobs
  SET
    status     = 'completed',
    updated_at = NOW()
  WHERE
    status IN ('assigned', 'in_progress', 'awaiting_confirmation')
    AND created_at < NOW() - INTERVAL '5 days';

  GET DIAGNOSTICS v_count_jobs = ROW_COUNT;

  -- marketplace_listings 동기화
  UPDATE public.marketplace_listings
  SET
    status    = 'completed',
    updatedat = NOW()
  WHERE
    status IN ('assigned', 'in_progress', 'awaiting_confirmation')
    AND createdat < NOW() - INTERVAL '5 days';

  GET DIAGNOSTICS v_count_listings = ROW_COUNT;

  RAISE NOTICE '[auto_complete_5days] jobs: %, listings: %', v_count_jobs, v_count_listings;
END;
$$;

-- 함수 즉시 실행 테스트
SELECT public.auto_complete_jobs_after_5days();

SELECT '✅ PART A 완료 - 함수 생성됨. pg_cron 활성화 후 PART B 실행하세요.' AS result;


-- ============================================================
-- PART B: pg_cron 스케줄 등록
-- ============================================================
-- ⚠️  아래 조건을 모두 충족한 뒤 실행하세요:
--   1) Supabase Dashboard → Database → Extensions
--      → "pg_cron" 검색 → Enable 클릭
--   2) PART A가 먼저 실행된 상태
-- ============================================================

-- 기존 동일 이름 잡 제거
SELECT cron.unschedule('auto-complete-jobs-5days');

-- 매일 KST 01:00 (UTC 16:00) 자동 실행 등록
SELECT cron.schedule(
  'auto-complete-jobs-5days',
  '0 16 * * *',
  'SELECT public.auto_complete_jobs_after_5days()'
);

-- 등록 확인
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname = 'auto-complete-jobs-5days';

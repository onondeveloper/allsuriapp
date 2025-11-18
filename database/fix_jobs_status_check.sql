-- jobs 테이블 status CHECK 제약조건 수정
-- 문제: 'awaiting_confirmation' 상태가 허용되지 않음
-- 에러: new row for relation "jobs" violates check constraint "jobs_status_check"

-- 1. 현재 CHECK 제약조건 확인
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'jobs'::regclass AND contype = 'c';

-- 2. 기존 CHECK 제약조건 삭제
ALTER TABLE public.jobs DROP CONSTRAINT IF EXISTS jobs_status_check;

-- 3. 새로운 CHECK 제약조건 추가 (awaiting_confirmation 포함)
ALTER TABLE public.jobs ADD CONSTRAINT jobs_status_check 
CHECK (status IN (
  'created', 
  'pending_transfer', 
  'assigned', 
  'in_progress',
  'awaiting_confirmation',  -- ✅ 추가
  'completed', 
  'cancelled'
));

-- 4. 확인
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'jobs'::regclass AND contype = 'c';

SELECT '✅ jobs status CHECK 제약조건 수정 완료!' as status;


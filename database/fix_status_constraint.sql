-- ==========================================
-- 🔧 marketplace_listings status 제약 조건 수정
-- awaiting_confirmation 상태 추가
-- ==========================================

-- 1. 현재 제약 조건 확인
SELECT '=== 현재 status CHECK 제약 조건 ===' as info;
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'marketplace_listings'::regclass
  AND contype = 'c'
  AND conname LIKE '%status%';

-- 2. 기존 제약 조건 삭제
ALTER TABLE public.marketplace_listings 
DROP CONSTRAINT IF EXISTS marketplace_listings_status_check;

-- 3. 새로운 제약 조건 생성 (awaiting_confirmation 추가)
ALTER TABLE public.marketplace_listings
ADD CONSTRAINT marketplace_listings_status_check 
CHECK (status IN (
  'created',
  'open',
  'assigned',
  'awaiting_confirmation',  -- ← 추가!
  'completed',
  'cancelled',
  'closed'
));

-- 4. jobs 테이블도 동일하게 수정
SELECT '=== jobs 테이블 status 제약 조건 수정 ===' as info;

ALTER TABLE public.jobs
DROP CONSTRAINT IF EXISTS jobs_status_check;

ALTER TABLE public.jobs
ADD CONSTRAINT jobs_status_check 
CHECK (status IN (
  'created',
  'pending',
  'assigned',
  'awaiting_confirmation',  -- ← 추가!
  'completed',
  'cancelled'
));

-- 5. 수정된 제약 조건 확인
SELECT '=== 수정된 marketplace_listings status 제약 조건 ===' as info;
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'marketplace_listings'::regclass
  AND contype = 'c'
  AND conname LIKE '%status%';

SELECT '=== 수정된 jobs status 제약 조건 ===' as info;
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'jobs'::regclass
  AND contype = 'c'
  AND conname LIKE '%status%';

SELECT '✅ status 제약 조건 수정 완료!' AS result;
SELECT '📋 이제 awaiting_confirmation 상태로 업데이트할 수 있습니다!' AS note;


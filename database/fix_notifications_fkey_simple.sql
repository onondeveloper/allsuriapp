-- ==========================================
-- 🔧 notifications 테이블 외래 키 제약 조건 수정 (간소화)
-- jobid, listingid만 처리 (estimateid 제외)
-- ==========================================

-- 1. jobid 외래 키 제약 조건 삭제
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_jobid_fkey;

-- 2. jobid 컬럼을 nullable로 변경
ALTER TABLE public.notifications
ALTER COLUMN jobid DROP NOT NULL;

-- 3. 새로운 jobid 외래 키 제약 조건 생성 (ON DELETE SET NULL)
ALTER TABLE public.notifications
ADD CONSTRAINT notifications_jobid_fkey
FOREIGN KEY (jobid)
REFERENCES jobs(id)
ON DELETE SET NULL;

-- 4. listingid 외래 키 제약 조건 삭제
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_listingid_fkey;

-- 5. listingid 컬럼을 nullable로 변경
ALTER TABLE public.notifications
ALTER COLUMN listingid DROP NOT NULL;

-- 6. 새로운 listingid 외래 키 제약 조건 생성 (ON DELETE SET NULL)
ALTER TABLE public.notifications
ADD CONSTRAINT notifications_listingid_fkey
FOREIGN KEY (listingid)
REFERENCES marketplace_listings(id)
ON DELETE SET NULL;

-- 7. 수정된 제약 조건 확인
SELECT '=== 수정된 notifications 외래 키 제약 조건 ===' as info;
SELECT 
    conname as constraint_name,
    confrelid::regclass as foreign_table,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'notifications'::regclass
  AND contype = 'f'
  AND conname IN ('notifications_jobid_fkey', 'notifications_listingid_fkey')
ORDER BY conname;

-- 8. nullable 컬럼 확인
SELECT '=== notifications 테이블 nullable 컬럼 ===' as info;
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
  AND column_name IN ('jobid', 'listingid')
ORDER BY column_name;

SELECT '✅ notifications 외래 키 제약 조건 수정 완료!' AS result;
SELECT '📋 이제 jobid가 없어도 알림을 전송할 수 있습니다!' AS note;


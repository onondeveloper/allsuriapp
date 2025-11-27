-- ==========================================
-- 🔧 notifications 외래 키 제약 조건 수정 (최소 버전)
-- jobid만 처리
-- ==========================================

-- 1. notifications 테이블 스키마 확인
SELECT '=== notifications 테이블 전체 컬럼 확인 ===' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. 현재 외래 키 제약 조건 확인
SELECT '=== notifications 외래 키 제약 조건 ===' as info;
SELECT 
    conname as constraint_name,
    confrelid::regclass as foreign_table,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'notifications'::regclass
  AND contype = 'f'
ORDER BY conname;

-- 3. jobid 외래 키 제약 조건 삭제 (있으면)
DO $$
BEGIN
    -- jobid 제약 조건 삭제
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'notifications'::regclass 
        AND conname = 'notifications_jobid_fkey'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_jobid_fkey;
        RAISE NOTICE 'notifications_jobid_fkey 제약 조건 삭제 완료';
    ELSE
        RAISE NOTICE 'notifications_jobid_fkey 제약 조건 없음 (스킵)';
    END IF;
END $$;

-- 4. jobid 컬럼이 존재하면 nullable로 변경
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'jobid'
    ) THEN
        ALTER TABLE public.notifications ALTER COLUMN jobid DROP NOT NULL;
        RAISE NOTICE 'jobid 컬럼을 nullable로 변경 완료';
    ELSE
        RAISE NOTICE 'jobid 컬럼이 존재하지 않음 (스킵)';
    END IF;
END $$;

-- 5. 새로운 jobid 외래 키 제약 조건 생성 (jobid 컬럼이 있는 경우만)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'jobid'
    ) THEN
        ALTER TABLE public.notifications
        ADD CONSTRAINT notifications_jobid_fkey
        FOREIGN KEY (jobid)
        REFERENCES jobs(id)
        ON DELETE SET NULL;
        RAISE NOTICE '새로운 jobid 외래 키 제약 조건 생성 완료';
    ELSE
        RAISE NOTICE 'jobid 컬럼이 없어 외래 키 생성 스킵';
    END IF;
END $$;

-- 6. 최종 확인
SELECT '=== 수정 완료 후 notifications 테이블 ===' as info;
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
  AND column_name LIKE '%job%' OR column_name LIKE '%listing%' OR column_name LIKE '%estimate%'
ORDER BY column_name;

SELECT '✅ notifications 외래 키 수정 완료!' AS result;
SELECT '📋 위의 컬럼 목록을 확인하고 실제 컬럼명을 알려주세요!' AS note;


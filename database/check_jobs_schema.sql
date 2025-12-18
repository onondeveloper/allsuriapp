-- ============================================
-- 🔍 jobs 테이블 스키마 확인
-- ============================================

-- 1️⃣ jobs 테이블의 모든 컬럼 조회
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'jobs'
ORDER BY ordinal_position;

-- 2️⃣ jobs 테이블의 샘플 데이터 확인 (벤허의 공사 1개)
SELECT *
FROM jobs
WHERE business_id = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
LIMIT 1;

-- 3️⃣ marketplace_listings와의 관계 확인
-- jobs 테이블에 marketplace_listings를 참조하는 컬럼 찾기
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'jobs'
    AND ccu.table_name = 'marketplace_listings';


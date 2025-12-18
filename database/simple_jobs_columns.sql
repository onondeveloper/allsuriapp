-- ============================================
-- 🔍 jobs 테이블 컬럼 이름만 간단히 확인
-- ============================================

-- jobs 테이블의 모든 컬럼 조회
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'jobs'
ORDER BY ordinal_position;


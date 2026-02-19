-- 중복 오더 방지 수정
-- Supabase SQL Editor에서 실행하세요

-- 1. 현재 중복된 오더 확인
SELECT jobid, COUNT(*) as count
FROM marketplace_listings
GROUP BY jobid
HAVING COUNT(*) > 1;

-- 2. 중복 오더 목록 확인 (삭제 전 확인)
SELECT id, jobid, title, status, createdat
FROM marketplace_listings
WHERE jobid IN (
    SELECT jobid
    FROM marketplace_listings
    GROUP BY jobid
    HAVING COUNT(*) > 1
)
ORDER BY jobid, createdat;

-- 3. 중복 오더 중 오래된 것 삭제 (최신 것만 남김)
-- ⚠️ 실행 전 위의 조회 결과를 반드시 확인하세요
DELETE FROM marketplace_listings
WHERE id IN (
    SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY jobid ORDER BY createdat DESC) as rn
        FROM marketplace_listings
    ) ranked
    WHERE rn > 1
);

-- 4. jobid UNIQUE 제약 확인 (이미 존재하면 추가 불필요)
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'marketplace_listings'
AND constraint_type = 'UNIQUE';

-- ✅ unique_jobid 제약이 이미 존재하면 ALTER TABLE 불필요

SELECT '✅ 중복 오더 제거 완료' AS status;

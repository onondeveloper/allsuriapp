-- 수동으로 실행할 수 있는 SQL 스크립트
-- jobs 테이블에 media_urls 컬럼 추가

-- 1. 컬럼 추가 (TEXT 배열 타입)
ALTER TABLE jobs ADD COLUMN media_urls TEXT[];

-- 2. 기존 데이터에 빈 배열로 초기화
UPDATE jobs SET media_urls = '{}' WHERE media_urls IS NULL;

-- 3. 기본값 설정
ALTER TABLE jobs ALTER COLUMN media_urls SET DEFAULT '{}';

-- 4. NOT NULL 제약 조건 추가
ALTER TABLE jobs ALTER COLUMN media_urls SET NOT NULL;

-- 5. 인덱스 생성 (배열 검색 성능 향상)
CREATE INDEX idx_jobs_media_urls ON jobs USING GIN (media_urls);

-- 6. 확인 쿼리
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'jobs' AND column_name = 'media_urls';

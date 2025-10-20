-- jobs 테이블에 media_urls 컬럼 추가
-- 이미지 URL들을 JSON 배열로 저장

-- 컬럼 추가
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS media_urls TEXT[];

-- 컬럼에 코멘트 추가
COMMENT ON COLUMN jobs.media_urls IS '공사 관련 이미지 URL 배열';

-- 기존 데이터에 대한 기본값 설정 (빈 배열)
UPDATE jobs SET media_urls = '{}' WHERE media_urls IS NULL;

-- 컬럼에 NOT NULL 제약 조건 추가 (기본값과 함께)
ALTER TABLE jobs ALTER COLUMN media_urls SET DEFAULT '{}';
ALTER TABLE jobs ALTER COLUMN media_urls SET NOT NULL;

-- 인덱스 추가 (선택사항 - 배열 검색 성능 향상)
CREATE INDEX IF NOT EXISTS idx_jobs_media_urls ON jobs USING GIN (media_urls);

SELECT '✅ jobs 테이블에 media_urls 컬럼이 성공적으로 추가되었습니다.' AS status;

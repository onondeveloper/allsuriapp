# Jobs 테이블에 media_urls 컬럼 추가

## 문제
공사 만들기 페이지에 사진 첨부 기능을 추가했지만, 데이터베이스의 `jobs` 테이블에 `media_urls` 컬럼이 존재하지 않아 오류가 발생합니다.

## 해결 방법

### 1. Supabase Dashboard에서 실행
Supabase Dashboard의 SQL Editor에서 다음 SQL을 실행하세요:

```sql
-- jobs 테이블에 media_urls 컬럼 추가 (TEXT 배열 타입)
ALTER TABLE jobs ADD COLUMN media_urls TEXT[];

-- 기존 데이터에 빈 배열로 초기화
UPDATE jobs SET media_urls = '{}' WHERE media_urls IS NULL;

-- 기본값 설정
ALTER TABLE jobs ALTER COLUMN media_urls SET DEFAULT '{}';

-- NOT NULL 제약 조건 추가
ALTER TABLE jobs ALTER COLUMN media_urls SET NOT NULL;

-- 인덱스 생성 (배열 검색 성능 향상)
CREATE INDEX idx_jobs_media_urls ON jobs USING GIN (media_urls);
```

### 2. 확인 쿼리
컬럼이 정상적으로 추가되었는지 확인:

```sql
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'jobs' AND column_name = 'media_urls';
```

### 3. 테스트
- 공사 만들기 페이지에서 사진을 첨부하고 공사를 등록해보세요
- 업로드된 이미지 URL이 `media_urls` 배열에 저장되는지 확인하세요

## 컬럼 정보
- **컬럼명**: `media_urls`
- **타입**: `TEXT[]` (텍스트 배열)
- **기본값**: `{}` (빈 배열)
- **제약조건**: NOT NULL
- **인덱스**: GIN 인덱스 (배열 검색 최적화)

## 주의사항
- 이 변경사항은 기존 데이터에 영향을 주지 않습니다
- 기존 `jobs` 레코드들은 빈 배열로 초기화됩니다
- 새로운 공사 등록 시에만 이미지 URL이 저장됩니다

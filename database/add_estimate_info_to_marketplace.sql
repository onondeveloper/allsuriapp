-- Call 공사 목록에 견적 정보 추가
-- marketplace_listings 테이블에 견적 금액과 이미지 컬럼 추가

ALTER TABLE public.marketplace_listings
ADD COLUMN IF NOT EXISTS estimate_amount NUMERIC,
ADD COLUMN IF NOT EXISTS media_urls TEXT[];

-- 인덱스 추가 (정렬용)
CREATE INDEX IF NOT EXISTS idx_marketplace_estimate_amount 
ON public.marketplace_listings(estimate_amount DESC);

-- 기존 데이터 업데이트 (budget_amount를 estimate_amount로 복사)
UPDATE public.marketplace_listings
SET estimate_amount = budget_amount
WHERE estimate_amount IS NULL AND budget_amount IS NOT NULL;

SELECT '✅ marketplace_listings 테이블에 견적 정보 컬럼 추가 완료' AS status;

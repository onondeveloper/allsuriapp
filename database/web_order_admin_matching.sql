-- ==========================================
-- 웹 견적 요청 → 관리자 매칭 시스템 설정
-- allsuri-web 에서 접수된 익명 견적을 관리자가
-- 사업자와 매칭하여 앱 '내 공사 관리'에 표시
--
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ==========================================

-- ==========================================
-- 1. jobs 테이블에 web_order_id 컬럼 추가
--    (웹 견적 요청과 공사를 연결하는 외래키)
-- ==========================================
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS web_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.jobs.web_order_id IS '웹 견적 요청(orders) ID - 관리자 매칭 시 설정됨';

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_jobs_web_order_id ON public.jobs(web_order_id);

-- ==========================================
-- 2. orders 테이블에 admin 매칭 관련 컬럼 추가
-- ==========================================
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS "adminNotes" TEXT,
  ADD COLUMN IF NOT EXISTS "adminRating" SMALLINT CHECK ("adminRating" BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS "adminRatingComment" TEXT,
  ADD COLUMN IF NOT EXISTS "adminRatedAt" TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "matchedJobId" UUID REFERENCES public.jobs(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.orders."adminNotes" IS '관리자 메모';
COMMENT ON COLUMN public.orders."adminRating" IS '관리자가 고객 확인 후 입력한 평점 (1-5)';
COMMENT ON COLUMN public.orders."adminRatingComment" IS '관리자 평점 코멘트';
COMMENT ON COLUMN public.orders."adminRatedAt" IS '평점 입력 일시';
COMMENT ON COLUMN public.orders."matchedJobId" IS '매칭된 공사(jobs) ID';

-- ==========================================
-- 3. RLS: authenticated 사용자가 anonymous 오더 조회 가능
--    (사업자가 앱에서 web-기반 공사 내역 확인 위해)
-- ==========================================
DROP POLICY IF EXISTS "authenticated_read_anonymous_orders" ON public.orders;

CREATE POLICY "authenticated_read_anonymous_orders" ON public.orders
FOR SELECT
TO authenticated
USING (
  "isAnonymous" = true
);

-- ==========================================
-- 4. RLS: service_role 이 jobs 테이블에 INSERT/UPDATE 가능
--    (Netlify 함수가 service role 키로 job 생성 시 필요)
-- ==========================================
-- service_role 은 기본적으로 RLS 를 bypass 하므로
-- 별도 정책 불필요. 이미 동작함.

-- ==========================================
-- 5. business_reviews 테이블에 admin 평점 지원
--    (없으면 생성, 있으면 컬럼 추가만)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.business_reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  order_id    UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  reviewer_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  is_admin_review BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 기존 테이블에 컬럼 추가 (이미 존재하는 경우 무시됨)
ALTER TABLE public.business_reviews
  ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_admin_review BOOLEAN DEFAULT FALSE;

-- RLS 활성화
ALTER TABLE public.business_reviews ENABLE ROW LEVEL SECURITY;

-- 기존 anon SELECT 정책 (이미 있음)
DROP POLICY IF EXISTS "anon_read_business_reviews" ON public.business_reviews;
CREATE POLICY "anon_read_business_reviews" ON public.business_reviews
FOR SELECT TO anon USING (true);

-- authenticated SELECT
DROP POLICY IF EXISTS "authenticated_read_business_reviews" ON public.business_reviews;
CREATE POLICY "authenticated_read_business_reviews" ON public.business_reviews
FOR SELECT TO authenticated USING (true);

-- ==========================================
-- 6. 결과 확인
-- ==========================================
SELECT '=== jobs 테이블 web_order_id 컬럼 ===' AS info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'jobs' AND column_name = 'web_order_id';

SELECT '=== orders 테이블 admin 컬럼 ===' AS info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders' AND column_name LIKE 'admin%';

SELECT '✅ 웹 견적 매칭 시스템 설정 완료!' AS status;

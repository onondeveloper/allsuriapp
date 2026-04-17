-- ====================================================
-- 웹 고객 견적 전체 플로우 수정 (원스탑 실행)
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ====================================================

-- ────────────────────────────────────────────────────
-- 1. orders 테이블 – 필수 컬럼 확인/추가
-- ────────────────────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS "webPassword"   VARCHAR(10),
  ADD COLUMN IF NOT EXISTS "isAnonymous"   BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS "customerName"  TEXT,
  ADD COLUMN IF NOT EXISTS "customerPhone" TEXT,
  ADD COLUMN IF NOT EXISTS "adminNotes"    TEXT,
  ADD COLUMN IF NOT EXISTS "adminRating"   SMALLINT CHECK ("adminRating" BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS "adminRatingComment" TEXT,
  ADD COLUMN IF NOT EXISTS "adminRatedAt"  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "matchedJobId"  UUID,
  ADD COLUMN IF NOT EXISTS "awardedEstimateId" UUID,
  ADD COLUMN IF NOT EXISTS "technicianId"  UUID,
  ADD COLUMN IF NOT EXISTS "isAwarded"     BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS "awardedAt"     TIMESTAMPTZ;

-- ────────────────────────────────────────────────────
-- 2. marketplace_listings – posted_by / jobid NULL 허용
--    웹 고객은 앱 계정 없음 → posted_by = null
--    웹 오더는 낙찰 전 job 없음 → jobid = null
-- ────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings
  ALTER COLUMN posted_by DROP NOT NULL;

ALTER TABLE public.marketplace_listings
  ALTER COLUMN jobid DROP NOT NULL;

-- ────────────────────────────────────────────────────
-- 3. marketplace_listings – 웹 오더 연결 컬럼
-- ────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS web_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS media_urls    TEXT[];

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_web_order
  ON public.marketplace_listings(web_order_id);

-- ────────────────────────────────────────────────────
-- 4. order_bids – 입찰 금액 / 공사 기일 컬럼
-- ────────────────────────────────────────────────────
ALTER TABLE public.order_bids
  ADD COLUMN IF NOT EXISTS bid_amount    NUMERIC,
  ADD COLUMN IF NOT EXISTS estimated_days INTEGER;

-- ────────────────────────────────────────────────────
-- 5. jobs 테이블 – 웹 오더 연결
-- ────────────────────────────────────────────────────
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS web_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;

-- ────────────────────────────────────────────────────
-- 6. RLS – authenticated 사용자가 익명(웹) 오더 조회
--    (관리자 패널, 앱에서 오더 목록 조회에 필요)
-- ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "authenticated_read_anonymous_orders" ON public.orders;
CREATE POLICY "authenticated_read_anonymous_orders" ON public.orders
  FOR SELECT TO authenticated
  USING ("isAnonymous" = true);

-- ────────────────────────────────────────────────────
-- 7. RLS – 웹 오더(status=open) 사업자 앱에서 조회
--    기존 sel_marketplace_listings 정책에 이미 포함돼 있으나
--    누락된 경우를 대비해 anon/authenticated 별도 정책 추가
-- ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "anon_read_open_listings" ON public.marketplace_listings;
CREATE POLICY "anon_read_open_listings" ON public.marketplace_listings
  FOR SELECT TO anon
  USING (status IN ('open', 'created'));

-- authenticated 는 기존 sel_marketplace_listings 정책이 처리
-- (status IN ('open','created','withdrawn') OR posted_by=uid() OR ...)
-- 이미 있으면 skip, 없으면 생성
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'marketplace_listings' AND policyname = 'sel_marketplace_listings'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "sel_marketplace_listings" ON public.marketplace_listings
      FOR SELECT TO authenticated, anon
      USING (
        status IN ('open', 'created', 'withdrawn')
        OR posted_by = auth.uid()
        OR claimed_by = auth.uid()
        OR selected_bidder_id = auth.uid()
      );
    $pol$;
    RAISE NOTICE 'sel_marketplace_listings 정책 생성됨';
  END IF;
END $$;

-- ────────────────────────────────────────────────────
-- 8. orders anon INSERT 허용 (웹 견적 직접 제출용)
-- ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "anon_web_orders_insert" ON public.orders;
CREATE POLICY "anon_web_orders_insert" ON public.orders
  FOR INSERT TO anon
  WITH CHECK ("isAnonymous" = true);

-- ────────────────────────────────────────────────────
-- 9. 인덱스 최적화
-- ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_orders_phone_password
  ON public.orders("customerPhone", "webPassword")
  WHERE "isAnonymous" = true;

CREATE INDEX IF NOT EXISTS idx_orders_is_anonymous
  ON public.orders("isAnonymous");

-- ────────────────────────────────────────────────────
-- 결과 확인
-- ────────────────────────────────────────────────────
SELECT '=== orders 컬럼 확인 ===' AS info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name IN ('webPassword','isAnonymous','customerPhone','customerName','matchedJobId','isAwarded')
ORDER BY column_name;

SELECT '=== marketplace_listings 컬럼 확인 ===' AS info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'marketplace_listings'
  AND column_name IN ('posted_by','web_order_id','media_urls','status')
ORDER BY column_name;

SELECT '=== order_bids 컬럼 확인 ===' AS info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'order_bids'
ORDER BY ordinal_position;

SELECT '✅ 웹 오더 전체 플로우 수정 완료!' AS status;

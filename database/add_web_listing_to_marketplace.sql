-- ==========================================
-- 웹 고객 견적 요청 → marketplace_listings 연동
-- 웹에서 접수된 오더가 앱 사업자 오더 목록에 표시되도록
--
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ==========================================

-- ==========================================
-- 1. marketplace_listings에 web_order_id 컬럼 추가
--    (orders 테이블과 연결)
-- ==========================================
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS web_order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.marketplace_listings.web_order_id IS '웹 고객 견적(orders.id) - 웹 제출 시 자동 연결';

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_web_order ON public.marketplace_listings(web_order_id);

-- ==========================================
-- 2. marketplace_listings RLS: 앱 사업자가 웹 오더 포함 모든 오픈 리스팅 조회
-- ==========================================

-- 기존 SELECT 정책이 있으면 유지하되, 없으면 생성
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'marketplace_listings' AND cmd = 'SELECT'
      AND roles::text LIKE '%authenticated%'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "authenticated_read_listings" ON public.marketplace_listings
      FOR SELECT TO authenticated
      USING (true);
    $pol$;
    RAISE NOTICE 'authenticated_read_listings 정책 생성됨';
  END IF;
END $$;

-- anon 도 오픈 리스팅 조회 가능 (웹 고객 '내 견적' 페이지에서 필요)
DROP POLICY IF EXISTS "anon_read_open_listings" ON public.marketplace_listings;
CREATE POLICY "anon_read_open_listings" ON public.marketplace_listings
FOR SELECT TO anon
USING (status IN ('open', 'created'));

-- ==========================================
-- 3. order_bids RLS 보완: 웹 오더의 입찰도 조회 가능하도록
-- ==========================================
-- 기존 정책에 web_order 연계 조건 추가 (기존 정책 있으면 skip)

-- ==========================================
-- 4. 결과 확인
-- ==========================================
SELECT '=== marketplace_listings web_order_id 컬럼 ===' AS info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'marketplace_listings' AND column_name = 'web_order_id';

SELECT '✅ 웹 오더 → marketplace_listings 연동 설정 완료!' AS status;

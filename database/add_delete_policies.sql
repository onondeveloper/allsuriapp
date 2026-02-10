-- ==========================================
-- 🔧 오더 삭제를 위한 DELETE RLS 정책 추가
-- ==========================================

-- 1. marketplace_listings DELETE 정책
-- 오더를 올린 소유자만 삭제 가능
DROP POLICY IF EXISTS delete_marketplace_listings ON public.marketplace_listings;

CREATE POLICY delete_marketplace_listings ON public.marketplace_listings
FOR DELETE
TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text
  OR auth.uid() IS NULL -- anon 허용
);

-- 2. jobs DELETE 정책
-- 공사를 생성한 소유자만 삭제 가능
DROP POLICY IF EXISTS delete_jobs ON public.jobs;

CREATE POLICY delete_jobs ON public.jobs
FOR DELETE
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL -- anon 허용
);

-- 3. order_bids DELETE 정책 (이미 있을 수 있지만 확실히 함)
-- 입찰자 또는 오더 소유자가 삭제 가능
DROP POLICY IF EXISTS delete_order_bids ON public.order_bids;

CREATE POLICY delete_order_bids ON public.order_bids
FOR DELETE
TO authenticated, anon
USING (
  bidder_id::text = (auth.uid())::text
  OR EXISTS (
    SELECT 1 FROM marketplace_listings
    WHERE id = order_bids.listing_id
    AND posted_by::text = (auth.uid())::text
  )
  OR auth.uid() IS NULL -- anon 허용
);

SELECT '✅ DELETE RLS 정책 추가 완료!' AS result;

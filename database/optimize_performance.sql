-- ==========================================
-- 🚀 성능 최적화를 위한 인덱스 추가
-- 자주 조회되는 컬럼에 인덱스를 생성하여 쿼리 속도 향상
-- ==========================================

-- 1. marketplace_listings 인덱스
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_posted_by ON public.marketplace_listings(posted_by);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_status ON public.marketplace_listings(status);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_claimed_by ON public.marketplace_listings(claimed_by);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_createdat ON public.marketplace_listings(createdat DESC);

-- 2. order_bids 인덱스
CREATE INDEX IF NOT EXISTS idx_order_bids_bidder_id ON public.order_bids(bidder_id);
CREATE INDEX IF NOT EXISTS idx_order_bids_listing_id ON public.order_bids(listing_id);
CREATE INDEX IF NOT EXISTS idx_order_bids_status ON public.order_bids(status);

-- 3. jobs 인덱스
CREATE INDEX IF NOT EXISTS idx_jobs_owner_business_id ON public.jobs(owner_business_id);
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_business_id ON public.jobs(assigned_business_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs(status);

-- 4. order_reviews 인덱스
CREATE INDEX IF NOT EXISTS idx_order_reviews_listing_id ON public.order_reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_reviewer_id ON public.order_reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_reviewee_id ON public.order_reviews(reviewee_id);

-- 5. notifications 인덱스
CREATE INDEX IF NOT EXISTS idx_notifications_userid ON public.notifications(userid);
CREATE INDEX IF NOT EXISTS idx_notifications_isread ON public.notifications(isread);
CREATE INDEX IF NOT EXISTS idx_notifications_createdat ON public.notifications(createdat DESC);

SELECT '✅ 성능 최적화 인덱스 생성 완료!' AS result;


-- 오더 리뷰 시스템
-- 오더 완료 후 사업자 평가 기능

-- 1. 리뷰 테이블 생성
CREATE TABLE IF NOT EXISTS public.order_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE, -- 리뷰 작성자 (오더 소유자)
  reviewee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE, -- 리뷰 대상 (오더를 가져간 사업자)
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5), -- 1~5 별점
  tags TEXT[] DEFAULT '{}', -- 선택한 태그들 (예: ['시간준수', '완벽처리', '깔끔정산', '친절'])
  comment TEXT, -- 추가 코멘트 (선택사항)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- 한 오더당 한 번만 리뷰 가능
  UNIQUE(listing_id, reviewer_id)
);

-- 2. 인덱스
CREATE INDEX IF NOT EXISTS idx_order_reviews_listing ON order_reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_reviewer ON order_reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_reviewee ON order_reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_rating ON order_reviews(rating);

-- 3. RLS 정책
ALTER TABLE public.order_reviews ENABLE ROW LEVEL SECURITY;

-- 리뷰 조회: 누구나 볼 수 있음 (공개)
DROP POLICY IF EXISTS select_order_reviews ON public.order_reviews;
CREATE POLICY select_order_reviews ON public.order_reviews
FOR SELECT
TO authenticated, anon
USING (true);

-- 리뷰 생성: 본인이 작성한 리뷰만
DROP POLICY IF EXISTS insert_order_reviews ON public.order_reviews;
CREATE POLICY insert_order_reviews ON public.order_reviews
FOR INSERT
TO authenticated, anon
WITH CHECK (reviewer_id = auth.uid());

-- 리뷰 수정: 본인이 작성한 리뷰만
DROP POLICY IF EXISTS update_order_reviews ON public.order_reviews;
CREATE POLICY update_order_reviews ON public.order_reviews
FOR UPDATE
TO authenticated, anon
USING (reviewer_id = auth.uid())
WITH CHECK (reviewer_id = auth.uid());

-- 4. users 테이블에 리뷰 통계 컬럼 추가
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS review_average DECIMAL(3,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS review_tags JSONB DEFAULT '{}';

-- 5. 리뷰 통계 업데이트 트리거
CREATE OR REPLACE FUNCTION update_user_review_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- reviewee의 통계 업데이트
  UPDATE users
  SET 
    review_count = (
      SELECT COUNT(*) 
      FROM order_reviews 
      WHERE reviewee_id = NEW.reviewee_id
    ),
    review_average = (
      SELECT ROUND(AVG(rating)::numeric, 2)
      FROM order_reviews 
      WHERE reviewee_id = NEW.reviewee_id
    ),
    review_tags = (
      SELECT jsonb_object_agg(tag, count)
      FROM (
        SELECT unnest(tags) as tag, COUNT(*) as count
        FROM order_reviews
        WHERE reviewee_id = NEW.reviewee_id
        GROUP BY tag
      ) AS tag_counts
    )
  WHERE id = NEW.reviewee_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_review_stats ON order_reviews;
CREATE TRIGGER trigger_update_review_stats
AFTER INSERT OR UPDATE ON order_reviews
FOR EACH ROW
EXECUTE FUNCTION update_user_review_stats();

-- 6. marketplace_listings에 완료 시간 컬럼 추가
ALTER TABLE public.marketplace_listings
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES public.users(id) ON DELETE SET NULL;

SELECT '✅ 오더 리뷰 시스템 구축 완료' AS status;


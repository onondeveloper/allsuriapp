-- 오더 경쟁 입찰 시스템
-- 여러 사업자가 하나의 오더에 입찰할 수 있도록 설계

-- 1. 오더 입찰 테이블 생성
CREATE TABLE IF NOT EXISTS public.order_bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
  bidder_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'selected', 'rejected', 'withdrawn')),
  message TEXT, -- 입찰 시 사업자가 남기는 메시지
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- 한 사업자는 같은 오더에 한 번만 입찰 가능
  UNIQUE(listing_id, bidder_id)
);

-- 2. marketplace_listings 테이블에 입찰 관련 컬럼 추가
ALTER TABLE public.marketplace_listings
ADD COLUMN IF NOT EXISTS bid_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS selected_bidder_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- 기존 claimed_by는 deprecated, selected_bidder_id 사용

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_order_bids_listing ON order_bids(listing_id);
CREATE INDEX IF NOT EXISTS idx_order_bids_bidder ON order_bids(bidder_id);
CREATE INDEX IF NOT EXISTS idx_order_bids_status ON order_bids(status);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_selected_bidder ON marketplace_listings(selected_bidder_id);

-- 4. RLS Policies
ALTER TABLE public.order_bids ENABLE ROW LEVEL SECURITY;

-- 입찰 조회: 본인이 입찰한 것, 또는 자신이 만든 오더의 모든 입찰
DROP POLICY IF EXISTS select_order_bids ON public.order_bids;
CREATE POLICY select_order_bids ON public.order_bids
FOR SELECT
TO authenticated, anon
USING (
  bidder_id = auth.uid() 
  OR EXISTS (
    SELECT 1 FROM marketplace_listings ml 
    WHERE ml.id = listing_id AND ml.posted_by = auth.uid()
  )
);

-- 입찰 생성: 인증된 사용자만
DROP POLICY IF EXISTS insert_order_bids ON public.order_bids;
CREATE POLICY insert_order_bids ON public.order_bids
FOR INSERT
TO authenticated, anon
WITH CHECK (bidder_id = auth.uid() OR auth.uid() IS NULL);

-- 입찰 업데이트: 본인 입찰만 (withdraw용)
DROP POLICY IF EXISTS update_order_bids ON public.order_bids;
CREATE POLICY update_order_bids ON public.order_bids
FOR UPDATE
TO authenticated, anon
USING (bidder_id = auth.uid() OR auth.uid() IS NULL);

-- 5. Trigger: 입찰 시 bid_count 자동 증가
CREATE OR REPLACE FUNCTION update_bid_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE marketplace_listings
    SET bid_count = bid_count + 1, updatedat = NOW()
    WHERE id = NEW.listing_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE marketplace_listings
    SET bid_count = GREATEST(0, bid_count - 1), updatedat = NOW()
    WHERE id = OLD.listing_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_bid_count ON order_bids;
CREATE TRIGGER trigger_update_bid_count
  AFTER INSERT OR DELETE ON order_bids
  FOR EACH ROW
  EXECUTE FUNCTION update_bid_count();

-- 6. Trigger: 입찰자 선택 시 selected_bidder_id 설정 및 다른 입찰 거절
CREATE OR REPLACE FUNCTION handle_bidder_selection()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'selected' AND OLD.status != 'selected' THEN
    -- marketplace_listings에 selected_bidder_id 설정
    UPDATE marketplace_listings
    SET selected_bidder_id = NEW.bidder_id, 
        status = 'assigned',
        claimed_by = NEW.bidder_id,
        claimed_at = NOW(),
        updatedat = NOW()
    WHERE id = NEW.listing_id;
    
    -- 같은 오더의 다른 입찰들을 rejected로 변경
    UPDATE order_bids
    SET status = 'rejected', updated_at = NOW()
    WHERE listing_id = NEW.listing_id 
      AND id != NEW.id 
      AND status = 'pending';
    
    -- jobs 테이블 업데이트
    IF NEW.job_id IS NOT NULL THEN
      UPDATE jobs
      SET assigned_business_id = NEW.bidder_id, 
          status = 'in_progress',
          updated_at = NOW()
      WHERE id = NEW.job_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_handle_bidder_selection ON order_bids;
CREATE TRIGGER trigger_handle_bidder_selection
  AFTER UPDATE ON order_bids
  FOR EACH ROW
  WHEN (NEW.status = 'selected')
  EXECUTE FUNCTION handle_bidder_selection();

-- 7. RPC: 입찰 생성
CREATE OR REPLACE FUNCTION create_order_bid(
  p_listing_id UUID,
  p_bidder_id UUID,
  p_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_bid_id UUID;
  v_job_id UUID;
BEGIN
  -- listing의 job_id 가져오기
  SELECT jobid INTO v_job_id
  FROM marketplace_listings
  WHERE id = p_listing_id;
  
  -- 입찰 생성
  INSERT INTO order_bids (listing_id, job_id, bidder_id, message, status)
  VALUES (p_listing_id, v_job_id, p_bidder_id, p_message, 'pending')
  RETURNING id INTO v_bid_id;
  
  RETURN v_bid_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: 입찰자 선택
CREATE OR REPLACE FUNCTION select_bidder(
  p_listing_id UUID,
  p_bidder_id UUID,
  p_owner_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_is_owner BOOLEAN;
BEGIN
  -- 오더 소유자 확인
  SELECT EXISTS(
    SELECT 1 FROM marketplace_listings
    WHERE id = p_listing_id AND posted_by = p_owner_id
  ) INTO v_is_owner;
  
  IF NOT v_is_owner THEN
    RAISE EXCEPTION '오더 소유자만 입찰자를 선택할 수 있습니다';
  END IF;
  
  -- 입찰 상태를 selected로 변경 (트리거가 나머지 처리)
  UPDATE order_bids
  SET status = 'selected', updated_at = NOW()
  WHERE listing_id = p_listing_id AND bidder_id = p_bidder_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. RPC: 입찰 취소
CREATE OR REPLACE FUNCTION withdraw_bid(
  p_bid_id UUID,
  p_bidder_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE order_bids
  SET status = 'withdrawn', updated_at = NOW()
  WHERE id = p_bid_id AND bidder_id = p_bidder_id AND status = 'pending';
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. RPC 실행 권한 부여
GRANT EXECUTE ON FUNCTION create_order_bid(UUID, UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION select_bidder(UUID, UUID, UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION withdraw_bid(UUID, UUID) TO authenticated, anon;

COMMIT;


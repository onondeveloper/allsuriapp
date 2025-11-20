-- 입찰자 선택 시 오더 상태를 '진행 중'(assigned)으로 변경하는 트리거
-- Supabase SQL Editor에서 실행

-- 1. 트리거 함수 생성/업데이트
CREATE OR REPLACE FUNCTION handle_bidder_selection()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'selected' AND OLD.status != 'selected' THEN
    -- marketplace_listings에 selected_bidder_id 설정 및 상태를 'assigned'로 변경
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
    
    -- jobs 테이블 업데이트 (상태를 'in_progress'로)
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

-- 2. 기존 트리거 삭제
DROP TRIGGER IF EXISTS trigger_handle_bidder_selection ON order_bids;

-- 3. 트리거 생성
CREATE TRIGGER trigger_handle_bidder_selection
  AFTER UPDATE ON order_bids
  FOR EACH ROW
  WHEN (NEW.status = 'selected')
  EXECUTE FUNCTION handle_bidder_selection();

-- 4. 확인
SELECT '✅ 입찰자 선택 트리거 업데이트 완료!' as status;

-- 테스트 쿼리:
-- 입찰 상태 확인
-- SELECT id, listing_id, bidder_id, status FROM order_bids WHERE listing_id = 'YOUR_LISTING_ID';

-- 오더 상태 확인
-- SELECT id, title, status, selected_bidder_id FROM marketplace_listings WHERE id = 'YOUR_LISTING_ID';


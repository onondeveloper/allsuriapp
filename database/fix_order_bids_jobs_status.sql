-- Fix order_bids trigger to use correct jobs status
-- Run this in Supabase SQL Editor

-- Update the trigger function to use 'assigned' instead of 'in_progress'
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
    
    -- jobs 테이블 업데이트 (status를 'assigned'로 변경)
    IF NEW.job_id IS NOT NULL THEN
      UPDATE jobs
      SET assigned_business_id = NEW.bidder_id, 
          status = 'assigned',  -- 'in_progress' 대신 'assigned' 사용
          updated_at = NOW()
      WHERE id = NEW.job_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger는 이미 존재하므로 재생성 불필요


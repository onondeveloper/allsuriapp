-- Fix claim_listing RPC to allow claiming 'created' status orders
-- This allows businesses to claim orders in 'created' status (not just 'open')

CREATE OR REPLACE FUNCTION claim_listing(p_listing_id UUID, p_business_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_result INTEGER;
  v_job_id UUID;
BEGIN
  -- Update marketplace_listings: allow claiming if status is 'open' OR 'created'
  UPDATE marketplace_listings
  SET 
    status = 'assigned',
    claimed_by = p_business_id,
    claimed_at = NOW(),
    updatedat = NOW()
  WHERE id = p_listing_id
    AND (status = 'open' OR status = 'created')  -- Allow both open and created
    AND (claimed_by IS NULL)
    AND posted_by != p_business_id  -- Cannot claim own order
  RETURNING jobid INTO v_job_id;
  
  GET DIAGNOSTICS v_result = ROW_COUNT;
  
  IF v_result > 0 THEN
    -- Update jobs table (use 'assigned' status, not 'in_progress')
    IF v_job_id IS NOT NULL THEN
      UPDATE jobs
      SET 
        assigned_business_id = p_business_id,
        status = 'assigned',
        updated_at = NOW()
      WHERE id = v_job_id;
    END IF;
    
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION claim_listing(UUID, UUID) TO authenticated, anon;


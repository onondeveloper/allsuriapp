-- Jobs table for business referral system
CREATE TABLE IF NOT EXISTS jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  owner_business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_business_id UUID REFERENCES users(id) ON DELETE SET NULL,
  transfer_to_business_id UUID REFERENCES users(id) ON DELETE SET NULL,
  budget_amount DECIMAL(12,2),
  awarded_amount DECIMAL(12,2),
  commission_rate DECIMAL(5,2) DEFAULT 5.00, -- Default 5% commission
  commission_amount DECIMAL(12,2),
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'pending_transfer', 'assigned', 'completed', 'cancelled')),
  location TEXT,
  category TEXT,
  urgency TEXT DEFAULT 'normal' CHECK (urgency IN ('low', 'normal', 'high', 'urgent')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_jobs_owner_business_id ON jobs(owner_business_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_category ON jobs(category);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at);

-- RLS policies
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- Business users can view all jobs
CREATE POLICY "Business users can view all jobs" ON jobs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'business'
    )
  );

-- Business users can create jobs
CREATE POLICY "Business users can create jobs" ON jobs
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'business'
    ) AND owner_business_id = auth.uid()
  );

-- Job owner can update their jobs
CREATE POLICY "Job owners can update their jobs" ON jobs
  FOR UPDATE USING (owner_business_id = auth.uid());

-- Job owner can delete their jobs
CREATE POLICY "Job owners can delete their jobs" ON jobs
  FOR DELETE USING (owner_business_id = auth.uid());

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER trigger_update_jobs_updated_at
  BEFORE UPDATE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_jobs_updated_at();

-- Function to calculate commission amount
CREATE OR REPLACE FUNCTION calculate_commission_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.awarded_amount IS NOT NULL AND NEW.commission_rate IS NOT NULL THEN
    NEW.commission_amount = (NEW.awarded_amount * NEW.commission_rate) / 100;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically calculate commission
CREATE TRIGGER trigger_calculate_commission
  BEFORE INSERT OR UPDATE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION calculate_commission_amount();

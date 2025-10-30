-- Fix RLS policies to allow anonymous users to create jobs
-- This allows the app to work even when Supabase Auth session is not properly set
-- Run this in Supabase SQL Editor

-- jobs: Allow anon users to insert jobs (will need to validate businessId on app side)
DROP POLICY IF EXISTS "Business users can create jobs" ON jobs;
CREATE POLICY "Business users can create jobs" ON jobs
  FOR INSERT 
  TO authenticated, anon
  WITH CHECK (
    -- If authenticated, check role
    (auth.uid() IS NOT NULL AND EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'business'
    ))
    -- If anonymous, allow (app will validate)
    OR (auth.uid() IS NULL)
  );

-- jobs: Allow anon users to read their own jobs
DROP POLICY IF EXISTS "Business users can view their own jobs" ON jobs;
CREATE POLICY "Business users can view their own jobs" ON jobs
  FOR SELECT
  TO authenticated, anon
  USING (
    owner_business_id = auth.uid() 
    OR assigned_business_id = auth.uid()
    OR auth.uid() IS NULL  -- Allow anon to read all
  );


-- Add count columns to users table for rating/tier system
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS estimates_created_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS jobs_accepted_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS projects_awarded_count INT DEFAULT 0;

-- Optional: Add indexes for these new columns if they will be frequently queried
CREATE INDEX IF NOT EXISTS idx_users_estimates_created_count ON public.users(estimates_created_count);
CREATE INDEX IF NOT EXISTS idx_users_jobs_accepted_count ON public.users(jobs_accepted_count);
CREATE INDEX IF NOT EXISTS idx_users_projects_awarded_count ON public.users(projects_awarded_count);

-- Function to increment estimates_created_count for a user
CREATE OR REPLACE FUNCTION increment_user_estimates_created_count(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET estimates_created_count = COALESCE(estimates_created_count, 0) + 1
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment jobs_accepted_count for a user
CREATE OR REPLACE FUNCTION increment_user_jobs_accepted_count(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET jobs_accepted_count = COALESCE(jobs_accepted_count, 0) + 1
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment projects_awarded_count for a user
CREATE OR REPLACE FUNCTION increment_user_projects_awarded_count(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET projects_awarded_count = COALESCE(projects_awarded_count, 0) + 1
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

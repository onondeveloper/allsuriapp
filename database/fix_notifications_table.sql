-- Fix notifications table structure
-- Run this in Supabase SQL Editor

-- Add missing columns if they don't exist
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS type TEXT,
ADD COLUMN IF NOT EXISTS postid UUID REFERENCES public.community_posts(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS jobid UUID REFERENCES public.jobs(id) ON DELETE CASCADE;

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_postid ON notifications(postid);
CREATE INDEX IF NOT EXISTS idx_notifications_jobid ON notifications(jobid);

-- Ensure userid column exists and has index
CREATE INDEX IF NOT EXISTS idx_notifications_userid ON notifications(userid);

-- Ensure isread column exists
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS isread BOOLEAN DEFAULT FALSE;

-- Create index for unread notifications
CREATE INDEX IF NOT EXISTS idx_notifications_isread ON notifications(isread);

COMMIT;


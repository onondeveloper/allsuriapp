-- Add postid column to notifications table for community post notifications
-- Run this in Supabase SQL Editor

-- Add postid column if it doesn't exist
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS postid UUID REFERENCES public.community_posts(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_notifications_postid ON notifications(postid);

-- Update existing comment notifications if any (optional, for data consistency)
-- This is safe to run even if there are no existing notifications
UPDATE notifications
SET postid = (
  SELECT postid 
  FROM community_comments 
  WHERE community_comments.id = notifications.jobid
)
WHERE type = 'comment' AND postid IS NULL AND jobid IS NOT NULL;

COMMIT;


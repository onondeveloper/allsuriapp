-- Add postid column to notifications table for community post notifications
-- Run this in Supabase SQL Editor

-- Add postid column if it doesn't exist
ALTER TABLE public.notifications
ADD COLUMN IF NOT EXISTS postid UUID REFERENCES public.community_posts(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_notifications_postid ON notifications(postid);

-- Note: The UPDATE statement for existing notifications is removed
-- because the 'type' column might not exist yet in the notifications table.
-- New notifications will be created with the correct postid automatically.

COMMIT;


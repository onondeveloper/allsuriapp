-- Add FCM token column to users table for push notifications

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Index for faster FCM token lookups
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token) WHERE fcm_token IS NOT NULL;

-- Comment
COMMENT ON COLUMN public.users.fcm_token IS 'Firebase Cloud Messaging token for push notifications';


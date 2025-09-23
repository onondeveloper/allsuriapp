-- Add avatar_url to users table
alter table public.users add column if not exists avatar_url text;

-- Create storage buckets (run in Supabase SQL):
-- SELECT storage.create_bucket('profiles', public:=true);
-- SELECT storage.create_bucket('attachments_jobs', public:=true);
-- SELECT storage.create_bucket('attachments_messages', public:=true);

-- Example policies (allow read public, write by owner)
-- Profiles
-- create policy if not exists profiles_read on storage.objects for select using (bucket_id = 'profiles');
-- create policy if not exists profiles_write on storage.objects for insert with check (
--   bucket_id = 'profiles' and auth.uid()::text = (storage.foldername(name))[1]
-- );



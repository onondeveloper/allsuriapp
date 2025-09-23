-- Extend messages table for image messages
alter table public.messages add column if not exists type text default 'text';
alter table public.messages add column if not exists image_url text;

-- Optional index for createdat
create index if not exists idx_messages_createdat on public.messages(createdat);

-- Storage bucket for message attachments (run in Supabase):
-- SELECT storage.create_bucket('attachments_messages', public:=true);
-- Policies (example): allow read public; allow insert by authenticated users
-- create policy if not exists msg_attachments_read on storage.objects for select using (bucket_id = 'attachments_messages');
-- create policy if not exists msg_attachments_write on storage.objects for insert with check (bucket_id = 'attachments_messages');



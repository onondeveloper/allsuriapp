-- 채팅방 테이블 스키마 확인
-- Supabase SQL Editor에서 실행

-- 1. chat_rooms 테이블 스키마 확인
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'chat_rooms'
ORDER BY ordinal_position;

-- 2. 최근 생성된 채팅방 확인
SELECT *
FROM chat_rooms
ORDER BY createdat DESC
LIMIT 10;

-- 3. chat_messages 테이블 존재 확인 및 생성
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'text',
  createdat TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_createdat ON chat_messages(createdat DESC);

-- 4. chat_rooms 테이블에 participant 컬럼 추가
ALTER TABLE chat_rooms
ADD COLUMN IF NOT EXISTS participant_a UUID REFERENCES users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS participant_b UUID REFERENCES users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS listingid UUID REFERENCES marketplace_listings(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS jobid UUID REFERENCES jobs(id) ON DELETE CASCADE;

-- 5. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_a ON chat_rooms(participant_a);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_b ON chat_rooms(participant_b);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_listingid ON chat_rooms(listingid);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_jobid ON chat_rooms(jobid);

-- 6. RLS 정책 (chat_messages)
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS select_chat_messages ON public.chat_messages;
CREATE POLICY select_chat_messages ON public.chat_messages
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS insert_chat_messages ON public.chat_messages;
CREATE POLICY insert_chat_messages ON public.chat_messages
FOR INSERT TO authenticated, anon
WITH CHECK (true);

SELECT '✅ chat_rooms 및 chat_messages 테이블 스키마 업데이트 완료' AS status;


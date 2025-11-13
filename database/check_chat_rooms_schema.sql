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

-- 3. participant_a, participant_b 컬럼이 없다면 추가
ALTER TABLE chat_rooms
ADD COLUMN IF NOT EXISTS participant_a UUID REFERENCES users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS participant_b UUID REFERENCES users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS listingid UUID REFERENCES marketplace_listings(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS jobid UUID REFERENCES jobs(id) ON DELETE CASCADE;

-- 4. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_a ON chat_rooms(participant_a);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_b ON chat_rooms(participant_b);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_listingid ON chat_rooms(listingid);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_jobid ON chat_rooms(jobid);

SELECT '✅ chat_rooms 테이블 스키마 업데이트 완료' AS status;


-- 채팅 읽음 상태 추적 기능 추가
-- Supabase SQL Editor에서 실행하세요

-- 1. chat_rooms 테이블에 마지막 읽은 시간 필드 추가
ALTER TABLE chat_rooms 
ADD COLUMN IF NOT EXISTS participant_a_last_read_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS participant_b_last_read_at TIMESTAMPTZ;

-- 2. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_a_read 
ON chat_rooms(participant_a, participant_a_last_read_at);

CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_b_read 
ON chat_rooms(participant_b, participant_b_last_read_at);

-- 3. 기존 채팅방의 읽음 시간을 현재 시간으로 초기화 (선택사항)
-- 이 쿼리는 기존 채팅방을 모두 읽은 것으로 표시합니다
-- UPDATE chat_rooms 
-- SET 
--   participant_a_last_read_at = NOW(),
--   participant_b_last_read_at = NOW()
-- WHERE participant_a_last_read_at IS NULL 
--    OR participant_b_last_read_at IS NULL;

SELECT '✅ 채팅 읽음 상태 추적 필드 추가 완료' AS status;


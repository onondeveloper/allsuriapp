-- 채팅방 데이터 확인
-- Supabase SQL Editor에서 실행

-- 1. chat_rooms 테이블의 모든 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'chat_rooms'
ORDER BY ordinal_position;

-- 2. chat_messages 테이블 존재 여부 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'chat_messages'
ORDER BY ordinal_position;

-- 3. 최근 생성된 채팅방 (모든 컬럼)
SELECT *
FROM chat_rooms
ORDER BY createdat DESC
LIMIT 10;

-- 4. 최근 메시지
SELECT *
FROM chat_messages
WHERE EXISTS (SELECT 1 FROM chat_messages)
ORDER BY createdat DESC
LIMIT 10;

-- 5. 특정 사용자의 채팅방 (participant 기준)
SELECT *
FROM chat_rooms
WHERE participant_a = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR participant_b = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR customerid = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
   OR businessid = '7cdd586f-e527-46a8-a4a1-db9ed4812248'
ORDER BY createdat DESC;


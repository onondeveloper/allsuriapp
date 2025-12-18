-- chat_messages 테이블에 image_url 필드 추가
-- Supabase SQL Editor에서 실행하세요

-- 1. image_url 컬럼 추가 (이미 존재하면 무시됨)
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. 인덱스 추가 (image_url이 있는 메시지 검색 최적화)
CREATE INDEX IF NOT EXISTS idx_chat_messages_image_url 
ON chat_messages(image_url) 
WHERE image_url IS NOT NULL;

SELECT '✅ chat_messages 테이블에 image_url 컬럼 추가 완료' AS status;


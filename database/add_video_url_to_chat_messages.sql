-- chat_messages 테이블에 video_url 필드 추가

-- 1. video_url 컬럼 추가 (이미 존재하면 무시됨)
ALTER TABLE chat_messages 
ADD COLUMN IF NOT EXISTS video_url TEXT;

-- 2. 인덱스 추가 (video_url이 있는 메시지 검색 최적화)
CREATE INDEX IF NOT EXISTS idx_chat_messages_video_url 
ON chat_messages(video_url) 
WHERE video_url IS NOT NULL;


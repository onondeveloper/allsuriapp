-- 공지 배너 테이블 생성
CREATE TABLE IF NOT EXISTS announcements (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message     TEXT NOT NULL,                     -- 공지 내용
  bg_color    TEXT NOT NULL DEFAULT '#1E3A8A',   -- 배경색 (hex)
  text_color  TEXT NOT NULL DEFAULT '#FFFFFF',   -- 글자색 (hex)
  is_active   BOOLEAN NOT NULL DEFAULT true,     -- 활성화 여부
  is_dismissible BOOLEAN NOT NULL DEFAULT true,  -- 닫기 버튼 표시 여부
  start_at    TIMESTAMPTZ,                       -- 노출 시작 (null = 즉시)
  end_at      TIMESTAMPTZ,                       -- 노출 종료 (null = 무기한)
  sort_order  INTEGER NOT NULL DEFAULT 0,        -- 여러 공지 시 노출 순서
  createdat   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updatedat   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS 활성화
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- 누구나 활성 공지 조회 가능 (앱에서 읽기 위해)
CREATE POLICY "Anyone can read active announcements"
  ON announcements FOR SELECT
  USING (true);

-- 테스트용 샘플 공지
INSERT INTO announcements (message, bg_color, text_color, is_active, is_dismissible)
VALUES ('👋 올수리 앱에 오신 것을 환영합니다!', '#1E3A8A', '#FFFFFF', true, true);

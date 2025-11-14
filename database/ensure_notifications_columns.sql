-- notifications 테이블에 필요한 모든 컬럼 확인 및 추가
-- Supabase SQL Editor에서 실행하세요

-- 1. 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userid UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  type TEXT NOT NULL,
  jobid TEXT,
  postid TEXT,
  isread BOOLEAN DEFAULT false,
  createdat TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updatedat TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 컬럼이 없으면 추가 (이미 있으면 에러 무시)
DO $$ 
BEGIN
  -- userid 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'userid'
  ) THEN
    ALTER TABLE notifications ADD COLUMN userid UUID REFERENCES users(id) ON DELETE CASCADE;
  END IF;

  -- title 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'title'
  ) THEN
    ALTER TABLE notifications ADD COLUMN title TEXT NOT NULL DEFAULT '';
  END IF;

  -- body 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'body'
  ) THEN
    ALTER TABLE notifications ADD COLUMN body TEXT;
  END IF;

  -- type 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'type'
  ) THEN
    ALTER TABLE notifications ADD COLUMN type TEXT NOT NULL DEFAULT 'general';
  END IF;

  -- jobid 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'jobid'
  ) THEN
    ALTER TABLE notifications ADD COLUMN jobid TEXT;
  END IF;

  -- postid 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'postid'
  ) THEN
    ALTER TABLE notifications ADD COLUMN postid TEXT;
  END IF;

  -- isread 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'isread'
  ) THEN
    ALTER TABLE notifications ADD COLUMN isread BOOLEAN DEFAULT false;
  END IF;

  -- createdat 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'createdat'
  ) THEN
    ALTER TABLE notifications ADD COLUMN createdat TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;

  -- updatedat 컬럼 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'updatedat'
  ) THEN
    ALTER TABLE notifications ADD COLUMN updatedat TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
END $$;

-- 3. 인덱스 생성 (성능 향상)
CREATE INDEX IF NOT EXISTS idx_notifications_userid ON notifications(userid);
CREATE INDEX IF NOT EXISTS idx_notifications_isread ON notifications(isread);
CREATE INDEX IF NOT EXISTS idx_notifications_createdat ON notifications(createdat DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- 4. RLS 정책 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 5. RLS 정책 생성 (이미 있으면 에러 무시)
DO $$ 
BEGIN
  -- 사용자가 자신의 알림만 볼 수 있도록
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'notifications' 
    AND policyname = 'Users can view their own notifications'
  ) THEN
    CREATE POLICY "Users can view their own notifications"
    ON notifications
    FOR SELECT
    TO authenticated
    USING (userid = auth.uid());
  END IF;

  -- 시스템이 알림을 생성할 수 있도록
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'notifications' 
    AND policyname = 'System can insert notifications'
  ) THEN
    CREATE POLICY "System can insert notifications"
    ON notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
  END IF;

  -- 사용자가 자신의 알림을 업데이트할 수 있도록 (읽음 표시)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'notifications' 
    AND policyname = 'Users can update their own notifications'
  ) THEN
    CREATE POLICY "Users can update their own notifications"
    ON notifications
    FOR UPDATE
    TO authenticated
    USING (userid = auth.uid());
  END IF;
END $$;

-- 6. 확인 쿼리
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- 성공 메시지
SELECT '✅ notifications 테이블 설정 완료!' as message;


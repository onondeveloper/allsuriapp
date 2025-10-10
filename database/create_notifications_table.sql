-- Notifications 테이블 생성 (없는 경우)

-- 1. 기존 테이블 확인
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications'
) AS table_exists;

-- 2. notifications 테이블 생성 (없으면)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    userid UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT,
    isread BOOLEAN DEFAULT FALSE,
    jobid UUID,
    estimateid UUID,
    orderid UUID,
    createdat TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updatedat TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_notifications_userid ON notifications(userid);
CREATE INDEX IF NOT EXISTS idx_notifications_isread ON notifications(isread);
CREATE INDEX IF NOT EXISTS idx_notifications_createdat ON notifications(createdat DESC);

-- 4. RLS (Row Level Security) 정책 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 5. RLS 정책: 사용자는 자신의 알림만 볼 수 있음
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = userid);

-- 6. RLS 정책: 사용자는 자신의 알림만 업데이트 가능
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (auth.uid() = userid);

-- 7. RLS 정책: 서비스 역할은 모든 알림 생성 가능
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
CREATE POLICY "Service role can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (true);

-- 완료 메시지
SELECT '✅ Notifications 테이블 생성 완료' AS status;

-- 테스트: 테이블 구조 확인
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;


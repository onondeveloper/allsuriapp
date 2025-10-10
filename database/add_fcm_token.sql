-- Users 테이블에 FCM 토큰 컬럼 추가

-- 1. fcm_token 컬럼 추가 (없는 경우)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'fcm_token'
    ) THEN
        ALTER TABLE users ADD COLUMN fcm_token TEXT;
        RAISE NOTICE 'fcm_token 컬럼이 추가되었습니다.';
    ELSE
        RAISE NOTICE 'fcm_token 컬럼이 이미 존재합니다.';
    END IF;
END $$;

-- 2. fcm_token에 인덱스 추가 (푸시 전송 시 빠른 조회를 위해)
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) 
WHERE fcm_token IS NOT NULL;

-- 3. 결과 확인
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'users' 
AND column_name = 'fcm_token';

SELECT '✅ FCM 토큰 컬럼 추가 완료' AS status;


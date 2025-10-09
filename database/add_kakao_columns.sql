-- 카카오 로그인 정보 저장을 위한 컬럼 추가
-- Supabase SQL Editor에서 실행하세요

-- 1. kakao_id 컬럼 추가 (카카오 고유 ID)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'kakao_id'
    ) THEN
        ALTER TABLE users ADD COLUMN kakao_id TEXT;
        CREATE INDEX IF NOT EXISTS idx_users_kakao_id ON users(kakao_id);
        RAISE NOTICE 'kakao_id 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'kakao_id 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 2. profile_image 컬럼 추가 (프로필 이미지 URL)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'profile_image'
    ) THEN
        ALTER TABLE users ADD COLUMN profile_image TEXT;
        RAISE NOTICE 'profile_image 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'profile_image 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 3. age_range 컬럼 추가 (연령대)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'age_range'
    ) THEN
        ALTER TABLE users ADD COLUMN age_range TEXT;
        RAISE NOTICE 'age_range 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'age_range 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 4. birthday 컬럼 추가 (생일, MMDD 형식)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'birthday'
    ) THEN
        ALTER TABLE users ADD COLUMN birthday TEXT;
        RAISE NOTICE 'birthday 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'birthday 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 5. gender 컬럼 추가 (성별)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'gender'
    ) THEN
        ALTER TABLE users ADD COLUMN gender TEXT;
        RAISE NOTICE 'gender 컬럼 추가 완료';
    ELSE
        RAISE NOTICE 'gender 컬럼이 이미 존재합니다';
    END IF;
END $$;

-- 6. 기존 사용자의 kakao_id 업데이트 (external_id에서 추출)
UPDATE users 
SET kakao_id = REPLACE(external_id, 'kakao:', '')
WHERE provider = 'kakao' 
  AND kakao_id IS NULL 
  AND external_id LIKE 'kakao:%';

-- 완료 메시지
SELECT '✅ 카카오 로그인 정보 컬럼 추가 완료' AS status;


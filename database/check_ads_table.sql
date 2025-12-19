-- ads 테이블 스키마 확인 및 필요한 컬럼 추가

-- 1. ads 테이블이 존재하는지 확인
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'ads'
) AS table_exists;

-- 2. ads 테이블의 현재 컬럼 확인
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'ads'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. ads 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS public.ads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  image_url TEXT,
  link_url TEXT,
  location TEXT NOT NULL DEFAULT 'home_banner',
  is_active BOOLEAN DEFAULT true,
  createdat TIMESTAMPTZ DEFAULT now(),
  updatedat TIMESTAMPTZ DEFAULT now()
);

-- 4. 필요한 컬럼이 없으면 추가
DO $$ 
BEGIN
  -- title 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'title'
  ) THEN
    ALTER TABLE ads ADD COLUMN title TEXT NOT NULL DEFAULT '';
  END IF;

  -- image_url 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE ads ADD COLUMN image_url TEXT;
  END IF;

  -- link_url 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'link_url'
  ) THEN
    ALTER TABLE ads ADD COLUMN link_url TEXT;
  END IF;

  -- location 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'location'
  ) THEN
    ALTER TABLE ads ADD COLUMN location TEXT NOT NULL DEFAULT 'home_banner';
  END IF;

  -- is_active 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE ads ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;

  -- createdat 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'createdat'
  ) THEN
    ALTER TABLE ads ADD COLUMN createdat TIMESTAMPTZ DEFAULT now();
  END IF;

  -- updatedat 컬럼 추가 (없으면)
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'ads' AND column_name = 'updatedat'
  ) THEN
    ALTER TABLE ads ADD COLUMN updatedat TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;

-- 5. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_ads_location ON ads(location);
CREATE INDEX IF NOT EXISTS idx_ads_is_active ON ads(is_active);
CREATE INDEX IF NOT EXISTS idx_ads_createdat ON ads(createdat DESC);

-- 6. 최종 스키마 확인
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'ads'
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '✅ ads 테이블 스키마 확인 및 업데이트 완료' AS status;


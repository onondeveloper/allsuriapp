-- ==========================================
-- 📢 광고 시스템 업그레이드 (위치 구분 추가)
-- ==========================================

-- 1. location 컬럼 추가
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS location TEXT DEFAULT 'dashboard_banner';

-- 2. 기존 데이터는 대시보드 배너로 설정
UPDATE public.ads SET location = 'dashboard_banner' WHERE location IS NULL;

-- 3. 홈 화면용 샘플 데이터 추가
INSERT INTO public.ads (title, image_url, link_url, is_active, location)
VALUES 
  ('홈 화면 배너 1', 'https://picsum.photos/800/400?random=10', 'https://blog.naver.com/jwcbsmg', true, 'home_banner'),
  ('홈 화면 배너 2', 'https://picsum.photos/800/400?random=11', 'https://google.com', true, 'home_banner');

-- 4. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_ads_location ON public.ads(location);

SELECT '✅ 광고 테이블 스키마 업데이트 완료!' AS result;


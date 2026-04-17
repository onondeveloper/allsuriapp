-- ================================================
-- 웹 콘텐츠 관리 시스템
-- allsuricommerce.netlify.app 사이트 설정 및 광고 배너
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ================================================

-- ── 1. 사이트 설정 테이블 ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.web_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 기본값 삽입 (이미 있으면 무시)
INSERT INTO public.web_settings (key, value) VALUES
  ('hero_title',            '집수리, 이제 올수리에서 해결하세요'),
  ('hero_subtitle',         '전문 업체 800곳 이상이 직접 견적서를 보내드립니다'),
  ('contact_phone',         ''),
  ('notice_banner',         ''),
  ('notice_banner_active',  'false')
ON CONFLICT (key) DO NOTHING;

-- RLS
ALTER TABLE public.web_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_read_web_settings" ON public.web_settings;
CREATE POLICY "anon_read_web_settings" ON public.web_settings
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "service_manage_web_settings" ON public.web_settings;
CREATE POLICY "service_manage_web_settings" ON public.web_settings
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 2. 웹 광고 배너 테이블 ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.web_ads (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  image_url   TEXT,
  link_url    TEXT,
  position    TEXT DEFAULT 'home_top',  -- home_top, home_middle, home_bottom, sidebar
  is_active   BOOLEAN DEFAULT true,
  sort_order  INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.web_ads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_read_web_ads" ON public.web_ads;
CREATE POLICY "anon_read_web_ads" ON public.web_ads
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS "service_manage_web_ads" ON public.web_ads;
CREATE POLICY "service_manage_web_ads" ON public.web_ads
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_web_ads_position ON public.web_ads(position) WHERE is_active = true;

SELECT '✅ 웹 콘텐츠 관리 테이블 생성 완료!' AS status;

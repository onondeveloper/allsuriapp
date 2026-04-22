-- ================================================
-- 추천 업체 + 푸시 알림 시스템
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ================================================

-- ── 1. 추천 업체 테이블 ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.web_featured_businesses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  sort_order  INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id)  -- 한 사업자를 중복 추가 방지
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_web_featured_businesses_sort
  ON public.web_featured_businesses(sort_order);

-- RLS
ALTER TABLE public.web_featured_businesses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_read_featured" ON public.web_featured_businesses;
CREATE POLICY "anon_read_featured" ON public.web_featured_businesses
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "service_manage_featured" ON public.web_featured_businesses;
CREATE POLICY "service_manage_featured" ON public.web_featured_businesses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

SELECT '✅ 추천 업체 + 푸시 알림 테이블 생성 완료!' AS status;

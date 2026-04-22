-- ================================================
-- 이번 달 우수 업체 (추천 업체) 테이블
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ================================================

-- ── 1. 테이블 생성 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.web_featured_businesses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  sort_order  INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 동일 사업자 중복 등록 방지
ALTER TABLE public.web_featured_businesses
  DROP CONSTRAINT IF EXISTS web_featured_businesses_user_id_key;
ALTER TABLE public.web_featured_businesses
  ADD CONSTRAINT web_featured_businesses_user_id_key UNIQUE (user_id);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_web_featured_businesses_sort
  ON public.web_featured_businesses(sort_order ASC);

-- ── 2. RLS 설정 ────────────────────────────────────────────────
ALTER TABLE public.web_featured_businesses ENABLE ROW LEVEL SECURITY;

-- 누구나 읽기 가능 (웹사이트 공개 표시)
DROP POLICY IF EXISTS "web_featured_anon_read" ON public.web_featured_businesses;
CREATE POLICY "web_featured_anon_read" ON public.web_featured_businesses
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- service_role 은 RLS 자동 bypass (별도 정책 불필요)

-- ── 3. 결과 확인 ───────────────────────────────────────────────
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'web_featured_businesses'
ORDER BY ordinal_position;

SELECT '✅ web_featured_businesses 테이블 생성 완료!' AS status;

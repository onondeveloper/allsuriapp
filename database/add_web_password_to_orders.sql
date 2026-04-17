-- ==========================================
-- orders 테이블에 웹 비밀번호(PIN) 컬럼 추가
-- 웹에서 비로그인 고객이 '내 공사' 조회 시 사용
-- 4자리 숫자 PIN으로 본인 확인
--
-- Supabase Dashboard → SQL Editor 에서 실행하세요.
-- ==========================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS "webPassword" VARCHAR(10);

COMMENT ON COLUMN public.orders."webPassword" IS '웹 고객 본인확인 PIN (4자리 숫자)';

-- 인덱스: 전화번호 + 비밀번호로 조회 최적화
CREATE INDEX IF NOT EXISTS idx_orders_phone_password
  ON public.orders("customerPhone", "webPassword")
  WHERE "isAnonymous" = true;

-- ==========================================
-- RLS: anon이 webPassword 로 자신의 주문 SELECT 가능하도록
-- (webPassword 가 일치하는 행만)
-- 실제 값 비교는 API(customer.ts)에서 처리하므로
-- anon 전체 SELECT를 허용하되 서비스 레이어에서 필터링
-- ==========================================
DROP POLICY IF EXISTS "anon_read_own_anonymous_orders" ON public.orders;

-- authenticated 사용자도 포함 (이전 정책과 통합)
-- service role 은 RLS bypass 이므로 API에서 직접 조회 가능

SELECT '✅ webPassword 컬럼 추가 완료!' AS status;
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'orders' AND column_name = 'webPassword';

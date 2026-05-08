-- ============================================================
-- 사업자 인증 우회(화이트리스트) 및 낙찰 게이트 강화
--
-- 적용 전제: database/business_verification.sql 가 먼저 적용되어
--   - users.business_verify_status / business_grace_until / businessnumber_norm 가 존재
--   - business_verifications 테이블 존재
--
-- 본 SQL이 추가하는 것:
--   1) users.business_verify_bypass + 관련 메타데이터 컬럼
--   2) 사업자 활동 가능 여부 통합 판정 함수 fn_business_can_act()
--   3) RLS 4건 (오더 등록/입찰/견적/공사) 갱신 — bypass 통과, 사업자번호 없으면
--      grace 기간 중에도 차단
--   4) select_bidder RPC 재정의 — 낙찰받을 사업자가 활동 가능해야만 진행
-- ============================================================

BEGIN;

-- 1) 컬럼 추가
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS business_verify_bypass        BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS business_verify_bypass_reason TEXT,
  ADD COLUMN IF NOT EXISTS business_verify_bypass_set_by UUID,
  ADD COLUMN IF NOT EXISTS business_verify_bypass_set_at TIMESTAMPTZ;

COMMENT ON COLUMN public.users.business_verify_bypass IS
  '관리자가 인증 절차를 면제한 사업자 여부. TRUE면 진위확인/사업자번호 입력 없이도 모든 사업자 기능 사용 가능.';

CREATE INDEX IF NOT EXISTS users_business_verify_bypass_idx
  ON public.users (business_verify_bypass)
  WHERE business_verify_bypass = TRUE;

-- 2) 통합 판정 함수
--    "이 사용자는 사업자 활동(오더/입찰/견적/공사)이 가능한가?"
--    조건:
--      (a) 관리자 우회(bypass=TRUE),
--      (b) 진위확인 완료(verified) 이며 사업자번호 보유,
--      (c) 유예 기간 안에 있고 사업자번호 보유.
--    사업자번호가 없으면 (a) 외에는 모두 차단.
DROP FUNCTION IF EXISTS public.fn_business_can_act(uuid);
CREATE OR REPLACE FUNCTION public.fn_business_can_act(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = p_uid
      AND u.role = 'business'
      AND u.businessstatus::text = 'approved'
      AND (
        u.business_verify_bypass = TRUE
        OR (
          u.businessnumber_norm IS NOT NULL
          AND (
            u.business_verify_status = 'verified'
            OR (
              u.business_grace_until IS NOT NULL
              AND u.business_grace_until > NOW()
            )
          )
        )
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.fn_business_can_act(uuid) TO authenticated, anon, service_role;

-- 3) RLS 갱신 (오더 생성/입찰/견적/공사) — fn_business_can_act 사용

-- 3-1) marketplace_listings (오더 생성)
DROP POLICY IF EXISTS ins_marketplace_listings ON public.marketplace_listings;
CREATE POLICY ins_marketplace_listings ON public.marketplace_listings
FOR INSERT
TO authenticated
WITH CHECK (
  posted_by::text = (auth.uid())::text
  AND public.fn_business_can_act(auth.uid())
);

-- 3-2) order_bids (입찰)
DROP POLICY IF EXISTS ins_order_bids ON public.order_bids;
CREATE POLICY ins_order_bids ON public.order_bids
FOR INSERT
TO authenticated
WITH CHECK (
  bidder_id::text = (auth.uid())::text
  AND public.fn_business_can_act(auth.uid())
);

-- 3-3) estimates (견적서)
DROP POLICY IF EXISTS ins_estimates ON public.estimates;
CREATE POLICY ins_estimates ON public.estimates
FOR INSERT
TO authenticated
WITH CHECK (
  businessid::text = (auth.uid())::text
  AND public.fn_business_can_act(auth.uid())
);

-- 3-4) jobs (공사 등록)
DROP POLICY IF EXISTS ins_jobs ON public.jobs;
CREATE POLICY ins_jobs ON public.jobs
FOR INSERT
TO authenticated
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  AND public.fn_business_can_act(auth.uid())
);

-- 4) select_bidder RPC 재정의
--    SECURITY DEFINER 라 RLS를 우회하지만, 함수 안에서 명시적으로 자격을 검사한다.
--    낙찰받을 사업자가 활동 가능 상태가 아니면 RAISE EXCEPTION으로 차단.
CREATE OR REPLACE FUNCTION public.select_bidder(
  p_listing_id UUID,
  p_bidder_id UUID,
  p_owner_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_owner   BOOLEAN;
  v_can_act    BOOLEAN;
BEGIN
  -- 오더 소유자 확인 (기존 동작 유지)
  SELECT EXISTS(
    SELECT 1 FROM public.marketplace_listings
    WHERE id = p_listing_id AND posted_by = p_owner_id
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION '오더 소유자만 입찰자를 선택할 수 있습니다'
      USING ERRCODE = 'P0001', HINT = 'NOT_OWNER';
  END IF;

  -- ⭐ 낙찰 게이트: 선택될 사업자가 활동 가능 상태여야 한다.
  SELECT public.fn_business_can_act(p_bidder_id) INTO v_can_act;
  IF NOT v_can_act THEN
    RAISE EXCEPTION '선택한 사업자는 사업자등록 진위확인이 완료되지 않아 낙찰할 수 없습니다.'
      USING ERRCODE = 'P0001', HINT = 'BIDDER_NOT_VERIFIED';
  END IF;

  -- 입찰 상태를 selected로 변경 (기존 트리거가 marketplace_listings 갱신/알림 처리)
  UPDATE public.order_bids
  SET status = 'selected', updated_at = NOW()
  WHERE listing_id = p_listing_id AND bidder_id = p_bidder_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.select_bidder(UUID, UUID, UUID) TO authenticated, anon;

COMMIT;

-- ============================================================
-- 점검 쿼리
-- ============================================================
SELECT '=== 활동 가능 사업자 ===' AS info;
SELECT id, name, businessname,
       business_verify_status,
       business_verify_bypass,
       businessnumber_norm IS NOT NULL AS has_b_no,
       business_grace_until,
       public.fn_business_can_act(id) AS can_act
FROM public.users
WHERE role = 'business'
ORDER BY can_act DESC, business_verify_status NULLS LAST
LIMIT 30;

-- ============================================================
-- 사업자등록정보 진위확인 (국세청 공공데이터 API 연동)
-- ============================================================
-- 적용 순서:
--   1) 본 SQL 실행 (컬럼/인덱스/감사 테이블/RLS/유예 백필)
--   2) Netlify Function business-verify 배포 후 BUSINESS_API_SERVICE_KEY 등록
--   3) 클라이언트 배포
--   4) 3일 유예 종료 후 자동 차단
-- ============================================================

BEGIN;

-- ============================================================
-- 1) users 테이블 컬럼 확장
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS business_repname        TEXT,
  ADD COLUMN IF NOT EXISTS business_open_date      DATE,
  ADD COLUMN IF NOT EXISTS business_verify_status  TEXT
      CHECK (business_verify_status IN ('unverified','verified','failed','closed'))
      DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS business_verified_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS business_verify_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS business_verify_last_attempt_at TIMESTAMPTZ,
  -- 유예 만료 시각: 이 시각까지는 인증 전이라도 등록/입찰 허용
  ADD COLUMN IF NOT EXISTS business_grace_until    TIMESTAMPTZ,
  -- 정규화된 사업자번호 (하이픈/공백 제거, 10자리). 중복 인덱스 키.
  ADD COLUMN IF NOT EXISTS businessnumber_norm     TEXT
      GENERATED ALWAYS AS (
        CASE
          WHEN businessnumber IS NULL THEN NULL
          WHEN length(regexp_replace(businessnumber, '[^0-9]', '', 'g')) = 10
            THEN regexp_replace(businessnumber, '[^0-9]', '', 'g')
          ELSE NULL
        END
      ) STORED;

COMMENT ON COLUMN public.users.business_verify_status IS
  '국세청 진위확인 결과: unverified|verified|failed|closed';
COMMENT ON COLUMN public.users.business_grace_until IS
  '유예 만료 시각. 진위확인 전이라도 이 시각까지는 등록/입찰 허용';

-- ============================================================
-- 2) 사업자번호 중복 방지 (verified 사용자 한해서만)
-- ============================================================
-- - verified가 아닌 행끼리는 중복 허용 (실패 흔적/미입력 사용자 충돌 방지)
-- - 한번 인증된 사업자번호는 다른 계정에서 다시 인증할 수 없음
DROP INDEX IF EXISTS users_businessnumber_norm_uniq;
CREATE UNIQUE INDEX users_businessnumber_norm_uniq
  ON public.users (businessnumber_norm)
  WHERE businessnumber_norm IS NOT NULL
    AND business_verify_status = 'verified';

-- 조회 가속용 보조 인덱스
CREATE INDEX IF NOT EXISTS users_business_verify_status_idx
  ON public.users (business_verify_status)
  WHERE role = 'business';

-- ============================================================
-- 3) 감사 이력 테이블 (business_verifications)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.business_verifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  businessnumber_norm TEXT NOT NULL,
  rep_name_masked TEXT,                  -- 평문 저장 금지. 예: '홍*동'
  open_date       DATE,
  api_endpoint    TEXT,                  -- 'validate' | 'status' | 'duplicate_check'
  api_response    JSONB,                 -- 응답 원본 (개인정보 최소화 후 저장)
  is_valid        BOOLEAN,
  reason          TEXT,                  -- 표준 코드: NOT_MATCHED|CLOSED|DUPLICATE|UPSTREAM_ERROR ...
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS business_verifications_user_id_idx
  ON public.business_verifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS business_verifications_b_no_idx
  ON public.business_verifications (businessnumber_norm, created_at DESC);

ALTER TABLE public.business_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bv_select_self ON public.business_verifications;
CREATE POLICY bv_select_self
  ON public.business_verifications
  FOR SELECT
  TO authenticated
  USING (user_id::text = (auth.uid())::text);

-- INSERT/UPDATE는 service role(서버 함수)만 수행. 별도 정책 없음.

-- ============================================================
-- 4) 기존 사업자 사용자에 대한 3일 유예 백필
-- ============================================================
-- 이미 사용 중인 approved 사업자는 마이그레이션 시각으로부터 3일 동안
-- 진위확인 없이도 등록/입찰 가능. 그 사이에 알림으로 인증 유도.
-- ⚠️ businessstatus는 ENUM(business_status) 이므로 빈 문자열로 COALESCE 하면 안된다.
--    NULL은 어차피 = 'approved'와 매칭되지 않으므로 그대로 비교한다.
UPDATE public.users
SET business_grace_until = NOW() + INTERVAL '3 days'
WHERE role = 'business'
  AND businessstatus::text = 'approved'
  AND business_verify_status <> 'verified'
  AND (business_grace_until IS NULL OR business_grace_until < NOW() + INTERVAL '3 days');

-- ============================================================
-- 5) 신규/전환 사용자 자동 유예 트리거
-- ============================================================
-- INSERT 또는 UPDATE 시 role/businessstatus가 business/approved가 되었는데
-- 진위확인이 안되어 있고 유예가 비어 있으면 3일 유예를 부여한다.
CREATE OR REPLACE FUNCTION public.fn_set_business_grace()
RETURNS TRIGGER AS $$
BEGIN
  -- businessstatus는 ENUM 이므로 NULL 안전 비교는 ::text 캐스팅으로 처리
  IF NEW.role = 'business'
     AND NEW.businessstatus::text = 'approved'
     AND COALESCE(NEW.business_verify_status, 'unverified') <> 'verified'
     AND NEW.business_grace_until IS NULL THEN
    NEW.business_grace_until := NOW() + INTERVAL '3 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_business_grace ON public.users;
CREATE TRIGGER trg_set_business_grace
  BEFORE INSERT OR UPDATE OF role, businessstatus
  ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_set_business_grace();

-- ============================================================
-- 6) RLS: 등록/입찰 시 (verified) 또는 (유예 중)만 허용
--    기존 enforce_business_approval_rls.sql 의 정책을 갱신
-- ============================================================

-- 6-1) marketplace_listings (오더 생성)
DROP POLICY IF EXISTS ins_marketplace_listings ON public.marketplace_listings;
CREATE POLICY ins_marketplace_listings ON public.marketplace_listings
FOR INSERT
TO authenticated
WITH CHECK (
  posted_by::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id::text = (auth.uid())::text
      AND u.role = 'business'
      AND u.businessstatus = 'approved'
      AND (
            u.business_verify_status = 'verified'
         OR (u.business_grace_until IS NOT NULL AND u.business_grace_until > NOW())
      )
  )
);

-- 6-2) order_bids (입찰)
DROP POLICY IF EXISTS ins_order_bids ON public.order_bids;
CREATE POLICY ins_order_bids ON public.order_bids
FOR INSERT
TO authenticated
WITH CHECK (
  bidder_id::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id::text = (auth.uid())::text
      AND u.role = 'business'
      AND u.businessstatus = 'approved'
      AND (
            u.business_verify_status = 'verified'
         OR (u.business_grace_until IS NOT NULL AND u.business_grace_until > NOW())
      )
  )
);

-- 6-3) estimates (견적서)
DROP POLICY IF EXISTS ins_estimates ON public.estimates;
CREATE POLICY ins_estimates ON public.estimates
FOR INSERT
TO authenticated
WITH CHECK (
  businessid::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id::text = (auth.uid())::text
      AND u.role = 'business'
      AND u.businessstatus = 'approved'
      AND (
            u.business_verify_status = 'verified'
         OR (u.business_grace_until IS NOT NULL AND u.business_grace_until > NOW())
      )
  )
);

-- 6-4) jobs (공사 등록)
DROP POLICY IF EXISTS ins_jobs ON public.jobs;
CREATE POLICY ins_jobs ON public.jobs
FOR INSERT
TO authenticated
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id::text = (auth.uid())::text
      AND u.role = 'business'
      AND u.businessstatus = 'approved'
      AND (
            u.business_verify_status = 'verified'
         OR (u.business_grace_until IS NOT NULL AND u.business_grace_until > NOW())
      )
  )
);

COMMIT;

-- ============================================================
-- 7) 점검 쿼리 (선택)
-- ============================================================
SELECT '=== 사용자 진위확인 상태 분포 ===' AS info;
SELECT business_verify_status, COUNT(*)
FROM public.users
WHERE role = 'business'
GROUP BY business_verify_status
ORDER BY 1;

SELECT '=== 유예 만료까지 잔여 시간 (상위 20명) ===' AS info;
SELECT id, businessname, business_verify_status,
       business_grace_until,
       business_grace_until - NOW() AS remaining
FROM public.users
WHERE role = 'business'
  AND business_verify_status <> 'verified'
ORDER BY business_grace_until NULLS FIRST
LIMIT 20;

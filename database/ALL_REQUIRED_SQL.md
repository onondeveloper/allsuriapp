# 🚨 필수 SQL 실행 목록

**중요**: 아래 SQL을 **순서대로** Supabase SQL Editor에서 실행해야 앱이 정상 작동합니다!

---

## ✅ 실행 순서

### 1️⃣ Status 제약 조건 수정 (필수!)
**파일**: `database/fix_status_constraint.sql`

```sql
-- awaiting_confirmation 상태 추가
ALTER TABLE public.marketplace_listings 
DROP CONSTRAINT IF EXISTS marketplace_listings_status_check;

ALTER TABLE public.marketplace_listings
ADD CONSTRAINT marketplace_listings_status_check 
CHECK (status IN (
  'created',
  'open',
  'assigned',
  'awaiting_confirmation',
  'completed',
  'cancelled',
  'closed'
));

ALTER TABLE public.jobs
DROP CONSTRAINT IF EXISTS jobs_status_check;

ALTER TABLE public.jobs
ADD CONSTRAINT jobs_status_check 
CHECK (status IN (
  'created',
  'pending',
  'assigned',
  'awaiting_confirmation',
  'completed',
  'cancelled'
));

SELECT '✅ Status 제약 조건 수정 완료!' AS result;
```

---

### 2️⃣ RLS 정책 수정 (필수!)
**파일**: `database/FINAL_RLS_FIX.sql`

```sql
-- marketplace_listings RLS 정책
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS upd_marketplace_listings ON public.marketplace_listings;

CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- jobs RLS 정책
DROP POLICY IF EXISTS update_jobs ON public.jobs;
DROP POLICY IF EXISTS update_jobs_policy ON public.jobs;

CREATE POLICY update_jobs ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- Realtime 활성화
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'marketplace_listings already in supabase_realtime';
  END;
  
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'order_bids already in supabase_realtime';
  END;
  
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
  EXCEPTION WHEN duplicate_object THEN
    RAISE NOTICE 'jobs already in supabase_realtime';
  END;
END $$;

SELECT '✅ RLS 정책 수정 완료!' AS result;
```

---

### 3️⃣ order_reviews RLS 정책 (필수!)
**파일**: `database/fix_order_reviews_rls.sql`

```sql
-- INSERT 정책
DROP POLICY IF EXISTS insert_order_reviews ON public.order_reviews;

CREATE POLICY insert_order_reviews ON public.order_reviews
FOR INSERT
TO authenticated, anon
WITH CHECK (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- UPDATE 정책
DROP POLICY IF EXISTS update_order_reviews ON public.order_reviews;

CREATE POLICY update_order_reviews ON public.order_reviews
FOR UPDATE
TO authenticated, anon
USING (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- SELECT 정책
DROP POLICY IF EXISTS select_order_reviews ON public.order_reviews;

CREATE POLICY select_order_reviews ON public.order_reviews
FOR SELECT
TO authenticated, anon
USING (true);

-- DELETE 정책
DROP POLICY IF EXISTS delete_order_reviews ON public.order_reviews;

CREATE POLICY delete_order_reviews ON public.order_reviews
FOR DELETE
TO authenticated, anon
USING (
  reviewer_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

ALTER TABLE public.order_reviews ENABLE ROW LEVEL SECURITY;

SELECT '✅ order_reviews RLS 정책 수정 완료!' AS result;
```

---

### 4️⃣ 사업자 통계 트리거 (권장)
**파일**: `database/update_user_statistics_triggers.sql`

```sql
-- 견적 올린 수 자동 업데이트
CREATE OR REPLACE FUNCTION update_estimates_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE users 
    SET estimates_created_count = estimates_created_count + 1
    WHERE id = NEW.businessid;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE users 
    SET estimates_created_count = GREATEST(0, estimates_created_count - 1)
    WHERE id = OLD.businessid;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_estimates_count ON estimates;
CREATE TRIGGER trg_update_estimates_count
AFTER INSERT OR DELETE ON estimates
FOR EACH ROW EXECUTE FUNCTION update_estimates_count();

-- 완료 건 수 자동 업데이트
CREATE OR REPLACE FUNCTION update_jobs_accepted_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'completed' THEN
    UPDATE users 
    SET jobs_accepted_count = jobs_accepted_count + 1
    WHERE id = NEW.assigned_business_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.status != 'completed' AND NEW.status = 'completed' THEN
    UPDATE users 
    SET jobs_accepted_count = jobs_accepted_count + 1
    WHERE id = NEW.assigned_business_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'completed' AND NEW.status != 'completed' THEN
    UPDATE users 
    SET jobs_accepted_count = GREATEST(0, jobs_accepted_count - 1)
    WHERE id = NEW.assigned_business_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_jobs_accepted_count ON jobs;
CREATE TRIGGER trg_update_jobs_accepted_count
AFTER INSERT OR UPDATE ON jobs
FOR EACH ROW EXECUTE FUNCTION update_jobs_accepted_count();

-- 기존 데이터 일괄 업데이트
UPDATE users u
SET estimates_created_count = (
  SELECT COUNT(*) FROM estimates e WHERE e.businessid = u.id
);

UPDATE users u
SET jobs_accepted_count = (
  SELECT COUNT(*) FROM jobs j 
  WHERE j.assigned_business_id = u.id AND j.status = 'completed'
);

SELECT '✅ 사업자 통계 트리거 생성 완료!' AS result;
```

---

### 5️⃣ notifications 스키마 확인 (알림 기능용)
**먼저 실행**: 실제 컬럼명 확인

```sql
-- notifications 테이블 컬럼 확인
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;
```

**결과를 보고** 실제 컬럼명이 `job_id`인지 `jobid`인지 확인 후 알려주세요!

---

## 📊 체크리스트

실행 후 체크:

- [ ] 1. Status 제약 조건 수정
- [ ] 2. RLS 정책 수정 (marketplace_listings, jobs)
- [ ] 3. order_reviews RLS 정책
- [ ] 4. 사업자 통계 트리거 (선택)
- [ ] 5. notifications 스키마 확인

---

## 🐛 문제 발생 시

각 SQL 실행 후 `✅` 메시지가 나타나야 합니다.

에러가 발생하면:
1. 에러 메시지 전체를 복사
2. 어떤 SQL에서 에러가 났는지 알려주세요

---

**마지막 업데이트**: 2025-11-27


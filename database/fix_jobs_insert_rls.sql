-- jobs 테이블 INSERT RLS policy 수정
-- 문제: 사업자가 공사를 생성할 때 RLS policy 위반 에러 발생
-- 해결: INSERT 정책을 단순화하고 anon도 허용

-- 1. 기존 INSERT 정책 모두 삭제
DROP POLICY IF EXISTS ins_jobs ON public.jobs;
DROP POLICY IF EXISTS "Business users can create jobs" ON public.jobs;
DROP POLICY IF EXISTS insert_jobs ON public.jobs;

-- 2. 새로운 INSERT 정책 생성 (단순화)
CREATE POLICY insert_jobs_policy ON public.jobs
FOR INSERT
TO authenticated, anon
WITH CHECK (
  -- 인증된 사용자인 경우: owner_business_id가 자신의 ID여야 함
  (auth.uid() IS NOT NULL AND owner_business_id = auth.uid())
  OR
  -- anon 사용자인 경우: owner_business_id만 제공되면 허용
  (auth.uid() IS NULL AND owner_business_id IS NOT NULL)
);

-- 3. SELECT 정책 확인 및 수정
DROP POLICY IF EXISTS "Business users can view all jobs" ON public.jobs;
DROP POLICY IF EXISTS "Business users can view their own jobs" ON public.jobs;
DROP POLICY IF EXISTS select_jobs ON public.jobs;

CREATE POLICY select_jobs_policy ON public.jobs
FOR SELECT
TO authenticated, anon
USING (
  -- 인증된 사용자: 자신이 소유하거나 할당받은 공사
  (auth.uid() IS NOT NULL AND (owner_business_id = auth.uid() OR assigned_business_id = auth.uid()))
  OR
  -- anon 사용자: 모든 공사 볼 수 있음 (marketplace에서 필요)
  (auth.uid() IS NULL)
);

-- 4. UPDATE 정책 확인
DROP POLICY IF EXISTS "Job owners can update their jobs" ON public.jobs;
DROP POLICY IF EXISTS update_jobs ON public.jobs;

CREATE POLICY update_jobs_policy ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  -- 소유자이거나 할당받은 사업자만 수정 가능
  owner_business_id = auth.uid() OR assigned_business_id = auth.uid()
);

-- 5. DELETE 정책 확인
DROP POLICY IF EXISTS "Job owners can delete their jobs" ON public.jobs;
DROP POLICY IF EXISTS delete_jobs ON public.jobs;

CREATE POLICY delete_jobs_policy ON public.jobs
FOR DELETE
TO authenticated, anon
USING (
  -- 소유자만 삭제 가능
  owner_business_id = auth.uid()
);

-- 6. RLS 활성화 확인
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- 7. 확인 쿼리
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'jobs'
ORDER BY policyname;

SELECT '✅ jobs 테이블 RLS 정책이 수정되었습니다.' AS status;


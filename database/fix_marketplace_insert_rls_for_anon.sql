-- ==========================================
-- marketplace_listings INSERT 정책 수정
-- anon 사용자(Supabase Auth 세션 없음)도 INSERT 가능하도록
-- ==========================================

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_marketplace_listings ON public.marketplace_listings;

-- 새 INSERT 정책: anon 사용자도 INSERT 가능
-- (posted_by가 유효한 business 사용자인지만 확인)
CREATE POLICY ins_marketplace_listings ON public.marketplace_listings
FOR INSERT
TO authenticated, anon
WITH CHECK (
  -- posted_by가 승인된 사업자인지 확인
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = marketplace_listings.posted_by
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

SELECT '✅ marketplace_listings INSERT RLS 정책 업데이트 완료' AS status;
SELECT '   anon 사용자도 INSERT 가능 (posted_by가 승인된 사업자인 경우)' AS info;

-- 테스트: 현재 정책 확인
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
FROM pg_policies
WHERE tablename = 'marketplace_listings' 
  AND cmd = 'INSERT'
ORDER BY policyname;


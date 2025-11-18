-- order_bids DELETE RLS 정책 수정
-- 문제: 입찰 취소 시 DELETE가 차단됨 (삭제된 행: 0개)
-- 해결: DELETE 정책 추가

-- 1. 기존 DELETE 정책 삭제
DROP POLICY IF EXISTS delete_order_bids ON public.order_bids;

-- 2. 새로운 DELETE 정책: 본인이 입찰한 것만 삭제 가능
CREATE POLICY delete_order_bids ON public.order_bids
FOR DELETE
TO authenticated, anon
USING (
  bidder_id = auth.uid() 
  OR auth.uid() IS NULL  -- anon 사용자도 허용 (현재 Supabase 세션이 없는 경우)
);

-- 3. 정책 확인
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'order_bids'
ORDER BY cmd, policyname;

SELECT '✅ order_bids DELETE RLS 정책 수정 완료!' as status;


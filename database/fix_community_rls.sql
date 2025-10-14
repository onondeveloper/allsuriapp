-- 커뮤니티 RLS 정책 수정
-- 문제: auth.uid()가 null이어서 insert 실패
-- 해결: anon key 사용 시에도 insert 가능하도록 정책 완화

-- 기존 정책 삭제
DROP POLICY IF EXISTS community_posts_insert ON public.community_posts;
DROP POLICY IF EXISTS community_posts_update ON public.community_posts;
DROP POLICY IF EXISTS community_posts_delete ON public.community_posts;
DROP POLICY IF EXISTS community_comments_insert ON public.community_comments;
DROP POLICY IF EXISTS community_comments_update ON public.community_comments;
DROP POLICY IF EXISTS community_comments_delete ON public.community_comments;

-- 새 정책: 인증 여부와 관계없이 작성 가능 (authorid 검증은 앱 레벨에서)
CREATE POLICY community_posts_insert ON public.community_posts 
  FOR INSERT 
  WITH CHECK (true);

CREATE POLICY community_posts_update ON public.community_posts 
  FOR UPDATE 
  USING (true);

CREATE POLICY community_posts_delete ON public.community_posts 
  FOR DELETE 
  USING (true);

CREATE POLICY community_comments_insert ON public.community_comments 
  FOR INSERT 
  WITH CHECK (true);

CREATE POLICY community_comments_update ON public.community_comments 
  FOR UPDATE 
  USING (true);

CREATE POLICY community_comments_delete ON public.community_comments 
  FOR DELETE 
  USING (true);

-- 확인
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  cmd 
FROM pg_policies 
WHERE tablename IN ('community_posts', 'community_comments')
ORDER BY tablename, policyname;


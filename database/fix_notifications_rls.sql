-- notifications 테이블 RLS 정책 수정
-- Supabase SQL Editor에서 실행

-- 1. 기존 정책 확인
SELECT '=== 현재 notifications 정책 ===' as info;
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'notifications' 
ORDER BY cmd;

-- 2. 기존 정책 모두 삭제
DROP POLICY IF EXISTS sel_notifications ON public.notifications;
DROP POLICY IF EXISTS ins_notifications ON public.notifications;
DROP POLICY IF EXISTS upd_notifications ON public.notifications;
DROP POLICY IF EXISTS del_notifications ON public.notifications;

-- 3. 새 정책 생성
-- SELECT: 본인의 알림만 조회 가능
CREATE POLICY sel_notifications ON public.notifications
FOR SELECT
TO authenticated, anon
USING (
  userid = auth.uid()::text
  OR userid = (SELECT id::text FROM auth.users WHERE id = auth.uid())
);

-- INSERT: 시스템(service role)만 생성 가능하도록 정책 없음
-- (Netlify Functions에서 service role key로 생성)

-- UPDATE: 본인의 알림만 수정 가능 (읽음 처리)
CREATE POLICY upd_notifications ON public.notifications
FOR UPDATE
TO authenticated, anon
USING (
  userid = auth.uid()::text
  OR userid = (SELECT id::text FROM auth.users WHERE id = auth.uid())
)
WITH CHECK (
  userid = auth.uid()::text
  OR userid = (SELECT id::text FROM auth.users WHERE id = auth.uid())
);

-- DELETE: 본인의 알림만 삭제 가능
CREATE POLICY del_notifications ON public.notifications
FOR DELETE
TO authenticated, anon
USING (
  userid = auth.uid()::text
  OR userid = (SELECT id::text FROM auth.users WHERE id = auth.uid())
);

-- 4. 테이블에 RLS 활성화
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 5. 확인
SELECT '✅ notifications RLS 정책 업데이트 완료!' as status;

-- 6. 데이터 확인 (현재 사용자의 알림)
SELECT '=== 현재 사용자 알림 확인 ===' as info;
SELECT id, userid, title, type, isread, createdat
FROM notifications
WHERE userid = auth.uid()::text
ORDER BY createdat DESC
LIMIT 10;

-- 7. 전체 알림 확인 (service role)
-- SELECT '=== 전체 알림 확인 (service role 전용) ===' as info;
-- SELECT id, userid, title, type, isread, createdat
-- FROM notifications
-- ORDER BY createdat DESC
-- LIMIT 10;


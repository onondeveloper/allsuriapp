-- 앱 내 회원 탈퇴 (Apple Guideline 5.1.1(v))
-- Supabase SQL Editor에서 실행하세요.
-- public.users 등은 auth.users 삭제 시 FK CASCADE 로 함께 제거되는 구성이 일반적입니다.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

COMMENT ON FUNCTION public.delete_my_account() IS '현재 로그인 사용자의 auth 계정 영구 삭제 (앱 회원 탈퇴)';

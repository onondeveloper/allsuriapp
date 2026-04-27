-- =============================================================
-- order_bids의 bidder_id 중 public.users에 없는 사용자 확인
-- =============================================================

-- 1. 누락된 사용자 확인 쿼리 (Supabase SQL Editor에서 실행)
SELECT DISTINCT ob.bidder_id
FROM public.order_bids ob
LEFT JOIN public.users u ON u.id = ob.bidder_id
WHERE u.id IS NULL
  AND ob.bidder_id IS NOT NULL;

-- 2. auth.users에 있는 사용자 정보를 public.users로 복원
-- (auth.users는 Supabase 내부 테이블이므로 별도 접근 필요)
-- Supabase Dashboard > SQL Editor에서 아래 쿼리 실행:
INSERT INTO public.users (id, name, businessname, email, role, businessstatus, created_at, updated_at)
SELECT
  au.id,
  COALESCE(au.raw_user_meta_data->>'name', au.raw_user_meta_data->>'full_name', split_part(au.email, '@', 1)) AS name,
  COALESCE(au.raw_user_meta_data->>'businessname', au.raw_user_meta_data->>'business_name',
           au.raw_user_meta_data->>'name', split_part(au.email, '@', 1)) AS businessname,
  au.email,
  COALESCE(au.raw_user_meta_data->>'role', 'business') AS role,
  COALESCE(au.raw_user_meta_data->>'businessstatus', 'approved') AS businessstatus,
  au.created_at,
  NOW()
FROM auth.users au
WHERE au.id IN (
  SELECT DISTINCT ob.bidder_id
  FROM public.order_bids ob
  LEFT JOIN public.users u ON u.id = ob.bidder_id
  WHERE u.id IS NULL
    AND ob.bidder_id IS NOT NULL
)
ON CONFLICT (id) DO NOTHING;

-- 3. 향후 신규 가입 시 public.users 자동 생성 트리거 (없는 경우에만)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, businessstatus, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'business'),
    COALESCE(NEW.raw_user_meta_data->>'businessstatus', 'pending'),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 트리거 등록 (이미 있으면 교체)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

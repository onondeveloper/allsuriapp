-- =============================================================
-- order_bids의 bidder_id 중 public.users에 없는 사용자 복원
-- Supabase Dashboard > SQL Editor에서 실행하세요
-- =============================================================

-- 1. 누락된 사용자 확인 (실행 후 결과 확인)
SELECT DISTINCT ob.bidder_id
FROM public.order_bids ob
LEFT JOIN public.users u ON u.id = ob.bidder_id
WHERE u.id IS NULL
  AND ob.bidder_id IS NOT NULL;

-- 2. auth.users 정보를 public.users로 복원
-- (위 쿼리 결과가 있으면 아래를 실행하세요)
INSERT INTO public.users (id, name, businessname, email, role, businessstatus, createdat)
SELECT
  au.id,
  COALESCE(
    NULLIF(au.raw_user_meta_data->>'businessname', ''),
    NULLIF(au.raw_user_meta_data->>'business_name', ''),
    NULLIF(au.raw_user_meta_data->>'preferred_username', ''),
    NULLIF(au.raw_user_meta_data->>'nickname', ''),
    NULLIF(au.raw_user_meta_data->>'full_name', ''),
    NULLIF(au.raw_user_meta_data->>'name', ''),
    split_part(au.email, '@', 1)
  ) AS name,
  COALESCE(
    NULLIF(au.raw_user_meta_data->>'businessname', ''),
    NULLIF(au.raw_user_meta_data->>'business_name', ''),
    NULLIF(au.raw_user_meta_data->>'preferred_username', ''),
    NULLIF(au.raw_user_meta_data->>'nickname', ''),
    NULLIF(au.raw_user_meta_data->>'full_name', ''),
    NULLIF(au.raw_user_meta_data->>'name', ''),
    split_part(au.email, '@', 1)
  ) AS businessname,
  au.email,
  COALESCE(au.raw_user_meta_data->>'role', 'business') AS role,
  'approved'::business_status AS businessstatus,
  au.created_at AS createdat
FROM auth.users au
WHERE au.id IN (
  SELECT DISTINCT ob.bidder_id
  FROM public.order_bids ob
  LEFT JOIN public.users u ON u.id = ob.bidder_id
  WHERE u.id IS NULL
    AND ob.bidder_id IS NOT NULL
)
ON CONFLICT (id) DO NOTHING;

-- 3. 이미 '카카오 사용자' 등 기본값으로 잘못 들어간 사용자 이름 수정
UPDATE public.users pu
SET
  name = COALESCE(
    NULLIF(au.raw_user_meta_data->>'businessname', ''),
    NULLIF(au.raw_user_meta_data->>'business_name', ''),
    NULLIF(au.raw_user_meta_data->>'preferred_username', ''),
    NULLIF(au.raw_user_meta_data->>'nickname', ''),
    NULLIF(au.raw_user_meta_data->>'full_name', ''),
    NULLIF(au.raw_user_meta_data->>'name', ''),
    split_part(au.email, '@', 1),
    pu.name
  ),
  businessname = COALESCE(
    NULLIF(au.raw_user_meta_data->>'businessname', ''),
    NULLIF(au.raw_user_meta_data->>'business_name', ''),
    NULLIF(au.raw_user_meta_data->>'preferred_username', ''),
    NULLIF(au.raw_user_meta_data->>'nickname', ''),
    NULLIF(au.raw_user_meta_data->>'full_name', ''),
    NULLIF(au.raw_user_meta_data->>'name', ''),
    split_part(au.email, '@', 1),
    pu.businessname
  )
FROM auth.users au
WHERE pu.id = au.id
  AND (pu.businessname IN ('카카오 사용자', '카카오유저', '사용자', '사업자') OR pu.businessname IS NULL OR pu.businessname = '');

-- 4. 복원 결과 확인
SELECT id, name, businessname, email, role, businessstatus
FROM public.users
WHERE id IN (
  SELECT DISTINCT bidder_id FROM public.order_bids WHERE bidder_id IS NOT NULL
)
ORDER BY createdat DESC
LIMIT 20;

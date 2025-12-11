-- ==========================================
-- 📢 광고 시스템 구축 (Ads Table)
-- ==========================================

-- 1. ads 테이블 생성
CREATE TABLE IF NOT EXISTS public.ads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT,
  image_url TEXT NOT NULL,
  link_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. RLS 정책 설정
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- 읽기 권한: 모든 사용자 (로그인, 비로그인 모두)
CREATE POLICY "Enable read access for all users" ON public.ads
FOR SELECT
TO anon, authenticated
USING (true);

-- 쓰기 권한: 관리자만 (일단은 authenticated로 열어두거나 추후 admin 체크 추가)
-- 여기서는 간단히 authenticated 사용자에게 허용 (실제 운영 시 admin role 체크 필요)
CREATE POLICY "Enable insert for authenticated users only" ON public.ads
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users only" ON public.ads
FOR UPDATE
TO authenticated
USING (true);

CREATE POLICY "Enable delete for authenticated users only" ON public.ads
FOR DELETE
TO authenticated
USING (true);

-- 3. Storage 버킷 생성 (이미지 저장용)
-- Supabase Dashboard에서 'ads'라는 이름의 Public Bucket을 생성해야 합니다.
-- SQL로는 버킷 생성이 제한될 수 있으니 Dashboard에서 확인해주세요.
-- 하지만 정책은 미리 설정 가능합니다.

-- storage.objects에 대한 정책 (ads 버킷)
-- 누구나 읽기 가능
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
TO public
USING ( bucket_id = 'ads' );

-- 로그인한 사용자는 업로드 가능
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'ads' );

-- 4. 샘플 데이터 삽입
INSERT INTO public.ads (title, image_url, link_url, is_active)
VALUES 
  (
    '샘플 광고 1', 
    'https://picsum.photos/800/400', -- 임시 이미지 URL
    'https://www.jw.org', 
    true
  ),
  (
    '샘플 광고 2', 
    'https://picsum.photos/800/400?random=2', -- 임시 이미지 URL
    'https://google.com', 
    true
  );

SELECT '✅ 광고 시스템 테이블 생성 완료!' AS result;


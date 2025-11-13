-- chat_rooms RLS 정책 수정
-- participant_a, participant_b로 조회 가능하도록 수정

-- RLS 활성화
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제
DROP POLICY IF EXISTS select_chat_rooms ON public.chat_rooms;

-- 새 정책 생성: 참가자만 조회 가능
CREATE POLICY select_chat_rooms ON public.chat_rooms
FOR SELECT
TO authenticated, anon
USING (
  participant_a = auth.uid() 
  OR participant_b = auth.uid()
  OR customerid = auth.uid()
  OR businessid = auth.uid()
);

-- INSERT 정책
DROP POLICY IF EXISTS insert_chat_rooms ON public.chat_rooms;
CREATE POLICY insert_chat_rooms ON public.chat_rooms
FOR INSERT
TO authenticated, anon
WITH CHECK (
  participant_a = auth.uid() 
  OR participant_b = auth.uid()
  OR customerid = auth.uid()
  OR businessid = auth.uid()
);

-- UPDATE 정책
DROP POLICY IF EXISTS update_chat_rooms ON public.chat_rooms;
CREATE POLICY update_chat_rooms ON public.chat_rooms
FOR UPDATE
TO authenticated, anon
USING (
  participant_a = auth.uid() 
  OR participant_b = auth.uid()
  OR customerid = auth.uid()
  OR businessid = auth.uid()
);

SELECT '✅ chat_rooms RLS 정책 업데이트 완료' AS status;


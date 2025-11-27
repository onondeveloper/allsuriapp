# 🚨 핵심 에러 수정 가이드

## 문제 상황

### 1. 채팅방 생성 실패
```
PostgrestException(message: estimateid_required, code: 23502, 
details: estimateid is required, hint: null)
```

**원인**: 
- `chat_rooms` 테이블의 `estimateid` 컬럼이 NOT NULL
- 오더 시스템에서는 `estimateid`가 없고 `listingId`를 사용

### 2. 공사 완료 실패
```
marketplace_listings 업데이트 결과: 0개 행 ⚠️ (RLS 차단?)
jobs 업데이트 결과: 0개 행 ⚠️ (RLS 차단?)
```

**원인**: 
- RLS 정책이 `claimed_by` (낙찰받은 사업자)의 UPDATE를 차단
- RLS 정책이 `assigned_business_id` (배정된 사업자)의 UPDATE를 차단

## 🔧 해결 방법

### 필수 단계: Supabase SQL 실행

**중요**: 다음 SQL을 Supabase SQL Editor에서 **반드시** 실행해야 합니다!

1. https://supabase.com 로그인
2. 프로젝트 선택
3. 왼쪽 메뉴에서 "SQL Editor" 클릭
4. "New Query" 클릭
5. `database/fix_complete_job_rls.sql` 파일 내용 복사 & 붙여넣기
6. "Run" 버튼 클릭

또는 아래 SQL을 직접 실행:

```sql
-- 1. marketplace_listings UPDATE 정책 수정
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;

CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE
TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text  -- ★ 핵심!
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text  -- ★ 핵심!
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- 2. jobs UPDATE 정책 수정
DROP POLICY IF EXISTS update_jobs ON public.jobs;

CREATE POLICY update_jobs ON public.jobs
FOR UPDATE
TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text  -- ★ 핵심!
  OR auth.uid() IS NULL
)
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text  -- ★ 핵심!
  OR auth.uid() IS NULL
);

-- 3. chat_rooms 스키마 수정
ALTER TABLE public.chat_rooms
ALTER COLUMN estimateid DROP NOT NULL;

ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS listingid UUID REFERENCES marketplace_listings(id) ON DELETE CASCADE;

ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS participant_a UUID REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS participant_b UUID REFERENCES users(id) ON DELETE CASCADE;

-- 4. chat_rooms RLS 정책
DROP POLICY IF EXISTS insert_chat_rooms ON public.chat_rooms;
CREATE POLICY insert_chat_rooms ON public.chat_rooms
FOR INSERT
TO authenticated, anon
WITH CHECK (
  participant_a::text = (auth.uid())::text
  OR participant_b::text = (auth.uid())::text
  OR customerid::text = (auth.uid())::text
  OR businessid::text = (auth.uid())::text
  OR auth.uid() IS NULL
);
```

### 확인 방법

SQL 실행 후 다음 쿼리로 확인:

```sql
-- UPDATE 정책 확인
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('marketplace_listings', 'jobs') AND cmd = 'UPDATE';

-- chat_rooms 스키마 확인
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_name = 'chat_rooms'
  AND column_name IN ('estimateid', 'listingid', 'participant_a', 'participant_b');
```

## 📱 Flutter 앱 재시작

SQL 실행 후:
1. 앱을 완전히 종료
2. 다시 실행 (Hot Reload가 아닌 완전 재시작)

## ✅ 테스트

### 테스트 1: 채팅방 생성
1. 오더 생성자로 로그인
2. "내 오더 관리" → 입찰자가 있는 오더 선택
3. "입찰자 보기" → 입찰자 선택
4. **예상 로그**:
   ```
   🔍 [ensureChatRoom] 채팅방 생성/조회 시작
      listingId: xxx
   ✅ [ensureChatRoom] 새 채팅방 생성 완료: xxx
   ```

### 테스트 2: 공사 완료
1. 낙찰받은 사업자로 로그인
2. "내 공사" → "진행 중" 탭
3. "공사 완료" 버튼 클릭
4. **예상 로그**:
   ```
   🔘 [Button] 공사 완료 버튼 클릭!
   marketplace_listings 업데이트 결과: 1개 행
   ✅ marketplace_listings 업데이트 성공
   jobs 업데이트 결과: 1개 행
   ✅ jobs 업데이트 성공
   ```

### 테스트 3: 실시간 업데이트
1. **사용자 A** (낙찰받은 사업자): 공사 완료 클릭
2. **사용자 B** (오더 생성자): "내 오더 관리" 화면에서 대기
3. **사용자 B의 예상 동작**:
   - 스낵바 표시: "공사가 완료되었습니다! 확인 후 리뷰를 작성해주세요."
   - 오더 상태 자동 업데이트 (assigned → awaiting_confirmation)

## 🎯 코드 변경 사항 (이미 적용됨)

### 1. `chat_service.dart`
- `listingId` 파라미터 추가
- `estimateid` 필수 제약 제거
- `participant_a`/`participant_b` 스키마 지원

### 2. `order_bidders_screen.dart`
```dart
chatRoomId = await chatService.ensureChatRoom(
  customerId: currentUserId,
  businessId: bidderId,
  listingId: widget.listingId, // ★ 추가됨
  title: 'order_${widget.listingId}',
);
```

## 📚 관련 파일

- `database/fix_complete_job_rls.sql` - 전체 수정 SQL
- `database/REALTIME_SETUP.md` - Realtime 설정 가이드
- `lib/services/chat_service.dart` - 채팅 서비스
- `lib/screens/business/order_bidders_screen.dart` - 입찰자 선택 화면

## ⚠️ 주의사항

1. **SQL을 실행하지 않으면 에러가 계속 발생합니다!**
2. Realtime도 활성화해야 실시간 업데이트가 작동합니다 (REALTIME_SETUP.md 참조)
3. 앱은 Hot Reload가 아닌 완전 재시작이 필요합니다

## 🆘 문제 해결

### 여전히 RLS 에러가 발생하는 경우

```sql
-- RLS 정책 확인
SELECT * FROM pg_policies 
WHERE tablename IN ('marketplace_listings', 'jobs', 'chat_rooms');

-- 정책이 없으면 다시 실행
\i database/fix_complete_job_rls.sql
```

### 채팅방 생성이 여전히 실패하는 경우

```sql
-- estimateid가 nullable인지 확인
SELECT column_name, is_nullable 
FROM information_schema.columns
WHERE table_name = 'chat_rooms' AND column_name = 'estimateid';

-- NO면 다시 실행
ALTER TABLE public.chat_rooms ALTER COLUMN estimateid DROP NOT NULL;
```

## 🎉 완료

모든 단계를 완료하면:
- ✅ 채팅방이 정상적으로 생성됩니다
- ✅ 공사 완료가 정상적으로 작동합니다
- ✅ 실시간 상태 업데이트가 작동합니다


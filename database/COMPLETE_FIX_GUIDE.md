# 🚨 공사 완료 문제 완전 해결 가이드

## 현재 상황

관리자 페이지 이미지를 보니 **많은 오더가 `AWAITING_CONFIRMATION` 상태**입니다!

이것은:
- ✅ 공사 완료 버튼은 작동함
- ✅ 로컬 상태는 변경됨
- ❌ **데이터베이스 업데이트는 실패함**

## 🔍 핵심 문제

### RLS 정책 중복

여러 개의 UPDATE 정책이 있으면, **모든 정책을 동시에 만족**해야 업데이트가 가능합니다.

**예시**:
- 정책 A: `posted_by` 또는 `claimed_by` 허용 ✅
- 정책 B: `posted_by`만 허용 ❌
- **결과**: 정책 B 때문에 차단됨! 💥

## ✅ 완전 해결 방법

### Step 1: 모든 중복 정책 제거

**Supabase SQL Editor**에서 다음 전체 SQL을 실행하세요:

`database/FINAL_RLS_FIX.sql` 파일 내용 전체를 복사하여 실행하거나, 아래 SQL을 실행:

```sql
-- marketplace_listings 모든 UPDATE 정책 삭제
DROP POLICY IF EXISTS update_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS upd_marketplace_listings ON public.marketplace_listings;
DROP POLICY IF EXISTS update_marketplace_listings_policy ON public.marketplace_listings;
DROP POLICY IF EXISTS "Business can update their listings" ON public.marketplace_listings;

-- 단일 정책 생성
CREATE POLICY update_marketplace_listings ON public.marketplace_listings
FOR UPDATE TO authenticated, anon
USING (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  posted_by::text = (auth.uid())::text
  OR claimed_by::text = (auth.uid())::text
  OR selected_bidder_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);

-- jobs 모든 UPDATE 정책 삭제
DROP POLICY IF EXISTS update_jobs ON public.jobs;
DROP POLICY IF EXISTS update_jobs_policy ON public.jobs;
DROP POLICY IF EXISTS upd_jobs ON public.jobs;
DROP POLICY IF EXISTS "Job owners can update their jobs" ON public.jobs;

-- 단일 정책 생성
CREATE POLICY update_jobs ON public.jobs
FOR UPDATE TO authenticated, anon
USING (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
)
WITH CHECK (
  owner_business_id::text = (auth.uid())::text
  OR assigned_business_id::text = (auth.uid())::text
  OR auth.uid() IS NULL
);
```

### Step 2: 확인

```sql
-- UPDATE 정책이 각 테이블에 1개씩만 있어야 함!
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('marketplace_listings', 'jobs')
  AND cmd = 'UPDATE'
ORDER BY tablename, policyname;
```

**예상 결과**: 정확히 2개의 행
```
marketplace_listings | update_marketplace_listings | UPDATE
jobs                 | update_jobs                 | UPDATE
```

### Step 3: Realtime 활성화

```sql
-- Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;
ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;

-- 확인
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('marketplace_listings', 'order_bids', 'jobs');
```

**예상 결과**: 3개의 행 모두 표시되어야 함

### Step 4: 사용자 통계 트리거 설정

```sql
-- database/update_user_statistics_triggers.sql 파일 내용 실행
-- 이것은 입찰자 정보 페이지의 "견적 올린 수", "완료 건 수"를 자동 계산합니다
```

---

## 🧪 테스트 프로세스

### 테스트 1: 공사 완료

1. **낙찰받은 사업자로 로그인**
2. "내 공사" → "진행 중" 탭
3. "공사 완료" 버튼 클릭
4. **로그 확인** (중요!):

**✅ 성공 로그**:
```
🔘 [_completeJob] 공사 완료 버튼 클릭!
🔄 [JobManagement] 공사 완료 처리 시작
   marketplace_listings 업데이트 중: xxx
   marketplace_listings 업데이트 결과: 1개 행  ✅✅✅
   ✅ marketplace_listings 업데이트 성공: awaiting_confirmation
   jobs 업데이트 결과: 1개 행  ✅✅✅
   ✅ jobs 업데이트 성공: awaiting_confirmation
```

**❌ 실패 로그**:
```
   marketplace_listings 업데이트 결과: 0개 행  ❌
   ⚠️ marketplace_listings UPDATE 실패 (RLS 차단?)
```

### 테스트 2: 실시간 알림

**오더 생성자 계정**에서:
1. "내 오더 관리" 화면 열기
2. 다른 기기/창에서 낙찰받은 사업자가 "공사 완료" 클릭
3. **예상 동작**:
   - 스낵바 표시: "공사가 완료되었습니다! 확인 후 리뷰를 작성해주세요."
   - 목록 자동 새로고침
   - 해당 오더 상태: "완료 확인 대기" (보라색)
   - **"리뷰 작성" 버튼 표시** (노란색)

4. **로그 확인**:
```
✅ [MyOrderManagement] 실시간 구독 상태: SUBSCRIBED
🔔 [MyOrderManagement] 내 오더 상태 변경 감지!
   Old: {status: assigned, ...}
   New: {status: awaiting_confirmation, completed_by: xxx}  ← completed_by 있어야 함!
   상태 변경: assigned → awaiting_confirmation
```

### 테스트 3: 리뷰 버튼

"내 오더 관리" → "진행 중" 탭에서:
- 상태 배지: **"완료 확인 대기"** (보라색) ✅
- **"리뷰 작성"** 버튼 (노란색/amber) ✅

**버튼이 안 보이면**:
```sql
-- 데이터베이스 직접 확인
SELECT 
  id,
  title,
  status,
  completed_by,
  completed_at,
  posted_by,
  claimed_by
FROM marketplace_listings
WHERE status = 'awaiting_confirmation';
```

**completed_by가 NULL이면** 업데이트가 실패한 것입니다!

---

## 🔧 지금 바로 실행

다음 파일들을 순서대로 Supabase에서 실행하세요:

### 1. RLS 정책 완전 정리
```bash
database/FINAL_RLS_FIX.sql
```

### 2. 사용자 통계 트리거
```bash
database/update_user_statistics_triggers.sql
```

---

## 📱 Flutter 앱 수정사항

<function_calls>
<invoke name="run_terminal_cmd">
<parameter name="command">cd /Users/hurmin-ho/Documents/dev/allsuriapp && git add -A && git commit -m "fix: 공사 완료 및 채팅 개선

1. 낙찰 후 채팅방 즉시 열림
   - 다이얼로그 제거
   - 스낵바로 빠른 피드백
   - 채팅방 자동 전환
   
2. 사용자 통계 트리거 SQL 추가
   - estimates_created_count 자동 계산
   - jobs_accepted_count 자동 계산
   - 기존 데이터 재계산
   
3. RLS 정책 완전 정리 SQL 추가
   - 중복 정책 모두 제거
   - 단일 정책으로 통일
   - Realtime 활성화 포함
   
문제:
- ❌ 공사 완료 시 DB 업데이트 실패
- ❌ 리뷰 버튼 안 보임
- ❌ 입찰자 통계 0으로 표시

해결:
- ✅ RLS 중복 정책 제거 SQL
- ✅ 사용자 통계 자동 업데이트
- ✅ 채팅방 즉시 열림"

# Supabase Realtime 설정 가이드

## 문제 상황
- 공사 완료 버튼을 눌러도 원 사업자에게 상태 변경이 실시간으로 반영되지 않음
- 입찰이 들어와도 오더 생성자에게 실시간 알림이 가지 않음

## 해결 방법

### 1. Supabase Realtime 활성화

Supabase SQL Editor에서 다음 스크립트를 실행:

```sql
-- marketplace_listings, order_bids, jobs 테이블에 Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;
ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
```

또는 `enable_realtime_for_orders.sql` 파일을 실행하세요.

### 2. Realtime 활성화 확인

```sql
-- 현재 Realtime이 활성화된 테이블 목록 확인
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

다음 테이블들이 목록에 있어야 합니다:
- `marketplace_listings`
- `order_bids`
- `jobs` (선택적)

### 3. Flutter 앱 재시작

Realtime이 활성화된 후 Flutter 앱을 재시작하세요.

## 작동 방식

### 공사 완료 프로세스

1. **낙찰받은 사업자 (A)**:
   - "진행 중" 탭에서 공사를 찾음
   - "공사 완료" 버튼 클릭
   - `marketplace_listings.status` → `awaiting_confirmation` 업데이트
   - `jobs.status` → `awaiting_confirmation` 업데이트

2. **원 사업자 (B, 오더 생성자)**:
   - `my_order_management_screen`에서 실시간 구독 중
   - Realtime 이벤트 수신:
     ```
     UPDATE on marketplace_listings
     WHERE posted_by = B
     ```
   - 목록 자동 새로고침
   - 스낵바 알림: "공사가 완료되었습니다! 확인 후 리뷰를 작성해주세요."

3. **원 사업자 확인 및 리뷰**:
   - "내 오더 관리" → "진행 중" 탭에서 확인
   - 상태: "확인 대기 중" → "리뷰 작성" 버튼 표시
   - 리뷰 작성 후 `marketplace_listings.status` → `completed`

## 디버깅

### 로그 확인

Flutter 앱 실행 중 다음 로그를 확인:

```
✅ [MyOrderManagement] 실시간 구독 상태: SUBSCRIBED
🔔 [MyOrderManagement] 내 오더 상태 변경 감지!
   Old: {status: assigned, ...}
   New: {status: awaiting_confirmation, ...}
   상태 변경: assigned → awaiting_confirmation
```

### 문제 해결

1. **구독 상태가 `SUBSCRIBED`가 아닌 경우**:
   - Supabase 프로젝트 설정에서 Realtime이 활성화되어 있는지 확인
   - 인터넷 연결 확인

2. **이벤트가 수신되지 않는 경우**:
   - RLS 정책 확인 (UPDATE 권한)
   - 필터 조건 확인 (`posted_by = currentUserId`)
   - `enable_realtime_for_orders.sql` 재실행

3. **공사 완료 버튼이 작동하지 않는 경우**:
   - 로그에서 `🔘 [Button] 공사 완료 버튼 클릭!` 메시지 확인
   - `job.status`가 `assigned` 또는 `in_progress`인지 확인
   - RLS UPDATE 정책 확인

## 참고

- Supabase Realtime 문서: https://supabase.com/docs/guides/realtime
- Flutter Supabase Realtime: https://supabase.com/docs/reference/dart/subscribe


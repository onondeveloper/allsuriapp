# 사용자 삭제 기능 설정 가이드 (CASCADE 삭제)

## 문제 상황
관리자 페이지에서 사용자(사업자 또는 고객)를 삭제하려고 할 때 500 에러가 발생합니다. 
이는 사용자와 연결된 다른 데이터(견적, 오더, 채팅 등)가 있어 Foreign Key 제약 조건 때문에 삭제가 불가능하기 때문입니다.

## 해결 방법
CASCADE 삭제를 수행하는 PostgreSQL 함수를 생성하여 사용자와 관련된 모든 데이터를 안전하게 삭제합니다.

### 생성된 함수:
1. **`delete_user_cascade(user_id)`**: 모든 사용자(사업자/고객) 삭제에 사용
2. **`delete_business_user(user_id)`**: 하위 호환성을 위한 별칭 (내부적으로 delete_user_cascade 호출)

## 설정 단계

### 1. Supabase SQL Editor 접속
1. [Supabase Dashboard](https://supabase.com/dashboard)에 로그인
2. 프로젝트 선택
3. 왼쪽 메뉴에서 `SQL Editor` 클릭

### 2. SQL 함수 실행
`delete_business_user_function.sql` 파일의 내용을 복사하여 SQL Editor에 붙여넣고 실행(Run)합니다.

### 3. 함수 확인
함수가 정상적으로 생성되었는지 확인:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN ('delete_user_cascade', 'delete_business_user');
```

결과로 두 함수가 모두 표시되어야 합니다.

### 4. 테스트 (선택사항)
테스트 사용자로 함수 작동 확인:
```sql
-- 삭제할 테스트 사용자 ID를 여기에 입력
SELECT delete_business_user('user-uuid-here'::UUID);
```

## 기능 설명

### 삭제되는 데이터:
1. **견적(estimates)**: 해당 사업자가 작성한 모든 견적
2. **입찰(order_bids)**: 해당 사업자의 모든 입찰
3. **마켓플레이스 리스팅**: 해당 사업자가 등록한 오더
4. **작업(jobs)**: 해당 사업자의 모든 작업
5. **채팅 메시지**: 해당 사업자가 보낸 메시지
6. **채팅방**: 해당 사업자가 참여한 채팅방
7. **알림**: 해당 사업자의 모든 알림
8. **커뮤니티 게시글/댓글**: 해당 사업자가 작성한 게시글과 댓글
9. **사용자 계정**: 마지막으로 사용자 계정 자체

### 반환 값:
```json
{
  "estimates": 5,
  "bids": 12,
  "listings": 3,
  "jobs": 8,
  "chats": 15,
  "notifications": 20,
  "user_deleted": true
}
```

## 관리자 페이지 변경사항

### 1. 관리자 지정 기능 추가
- 사용자 목록에 "관리자" 컬럼 추가
- 사용자 상세 모달에 "관리자 지정/해제" 버튼 추가
- 관리자 권한이 있는 사용자는 다른 사용자를 관리자로 지정할 수 있습니다

### 2. 사업자 삭제 개선
- 사업자 삭제 시 CASCADE 삭제 함수 사용
- 삭제 전 확인 메시지에 "관련된 모든 데이터도 함께 삭제됩니다" 안내 추가
- 일반 사용자는 일반 DELETE, 사업자는 CASCADE DELETE 사용

## 주의사항

⚠️ **중요**: 이 함수는 사용자와 관련된 모든 데이터를 영구적으로 삭제합니다. 
실행 전 반드시 확인하세요!

⚠️ **백업**: 중요한 데이터가 있는 경우 삭제 전 백업을 권장합니다.

## 문제 해결

### "function does not exist" 오류
- SQL 함수가 생성되지 않았습니다
- `delete_business_user_function.sql`을 다시 실행하세요

### "permission denied" 오류
- 함수 실행 권한이 없습니다
- SQL에 포함된 GRANT 문이 실행되었는지 확인하세요

### 여전히 500 에러 발생
1. 브라우저 콘솔에서 정확한 에러 메시지 확인
2. 백엔드 서버 로그 확인 (`backend/server.log`)
3. Supabase Dashboard의 Logs 섹션 확인


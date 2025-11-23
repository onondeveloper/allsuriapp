# Jobs 테이블 RLS Policy 수정 가이드

## 🔴 문제 상황

사업자가 공사를 생성할 때 다음 에러가 발생합니다:

```
PostgrestException(message: new row violates row-level security policy for table "jobs", code: 42501, details: Unauthorized, hint: null)
```

## 🔍 원인

1. **중복된 RLS 정책**: 여러 SQL 파일에서 정책을 여러 번 생성하여 충돌 발생
2. **너무 제한적인 정책**: 승인된 사업자만 INSERT 가능하도록 설정되어 있을 수 있음
3. **anon 사용자 제한**: Flutter 앱에서 anon 키로 접근하는 경우 차단됨

## ✅ 해결 방법

### 1. Supabase SQL Editor 접속
1. [Supabase Dashboard](https://supabase.com/dashboard) 로그인
2. 프로젝트 선택
3. 왼쪽 메뉴에서 **SQL Editor** 클릭

### 2. SQL 실행
`fix_jobs_insert_rls.sql` 파일의 전체 내용을 복사하여 SQL Editor에 붙여넣고 **Run** 클릭

### 3. 현재 정책 확인
수정 후 다음 쿼리로 확인:

```sql
SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'jobs'
ORDER BY policyname;
```

**예상 결과**:
- `insert_jobs_policy` - INSERT - {authenticated, anon}
- `select_jobs_policy` - SELECT - {authenticated, anon}
- `update_jobs_policy` - UPDATE - {authenticated, anon}
- `delete_jobs_policy` - DELETE - {authenticated, anon}

## 📋 새로운 정책 규칙

### INSERT (공사 생성)
- ✅ **인증된 사용자**: `owner_business_id`가 자신의 ID여야 함
- ✅ **anon 사용자**: `owner_business_id`만 제공되면 허용

### SELECT (공사 조회)
- ✅ **인증된 사용자**: 자신이 소유하거나 할당받은 공사만
- ✅ **anon 사용자**: 모든 공사 조회 가능 (marketplace에서 필요)

### UPDATE (공사 수정)
- ✅ **소유자** 또는 **할당받은 사업자**만 수정 가능

### DELETE (공사 삭제)
- ✅ **소유자**만 삭제 가능

## 🧪 테스트

SQL 실행 후:

1. **Flutter 앱에서 공사 생성** 테스트
   - "공사 만들기" → 정보 입력 → "오더로 올리기"
   - 에러 없이 생성되어야 함

2. **확인 쿼리**:
```sql
-- 최근 생성된 공사 확인
SELECT id, title, owner_business_id, status, created_at
FROM jobs
ORDER BY created_at DESC
LIMIT 5;
```

## ⚠️ 주의사항

- **기존 정책 삭제**: 이 SQL은 기존의 모든 jobs INSERT 정책을 삭제하고 새로 생성합니다
- **백업**: 중요한 경우 현재 정책을 백업하세요:
  ```sql
  SELECT * FROM pg_policies WHERE tablename = 'jobs';
  ```
- **권한 확인**: anon 사용자에게 너무 많은 권한이 부여되지 않도록 주의

## 🔄 문제 지속 시

만약 여전히 에러가 발생한다면:

1. **Flutter 앱 로그 확인**:
   - Supabase 클라이언트가 올바른 키(anon 또는 service_role)를 사용하는지 확인

2. **Supabase 로그 확인**:
   - Dashboard → Logs → Postgres Logs
   - 정확한 에러 메시지 확인

3. **사용자 인증 상태 확인**:
   ```dart
   final user = Supabase.instance.client.auth.currentUser;
   print('Current user: ${user?.id}');
   ```

4. **직접 테스트**:
   ```sql
   -- SQL Editor에서 직접 INSERT 테스트
   INSERT INTO jobs (
     title, 
     description, 
     owner_business_id, 
     status
   ) VALUES (
     'Test Job',
     'Test Description',
     'user-uuid-here',  -- 실제 사용자 UUID 입력
     'created'
   );
   ```


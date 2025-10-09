# 관리자 페이지 디버깅 가이드

## 문제: 사용자 목록이 표시되지 않음

### 1️⃣ Supabase 데이터 확인

1. **Supabase Dashboard 접속**
   - https://supabase.com/dashboard
   - 프로젝트 선택: `allsuriapp`

2. **SQL Editor에서 쿼리 실행**
   ```sql
   -- 모든 사용자 확인
   SELECT id, name, email, role, businessstatus, createdat
   FROM users
   ORDER BY createdat DESC
   LIMIT 20;
   ```

3. **결과 확인**
   - ✅ 데이터가 있으면: Step 2로 이동
   - ❌ 데이터가 없으면: 
     - 앱에서 다시 로그인 시도
     - 카카오 로그인 → 사업자 프로필 작성 → 저장
     - 다시 SQL 쿼리 실행

---

### 2️⃣ Netlify 환경 변수 확인

1. **Netlify Dashboard 접속**
   - https://app.netlify.com
   - Site: `allsuriapp` 선택

2. **환경 변수 확인**
   - Site Settings → Environment Variables
   - 다음 변수들이 설정되어 있는지 확인:
     ```
     SUPABASE_URL=https://iiunvogtqssxaxdnhqaj.supabase.co
     SUPABASE_SERVICE_ROLE_KEY=[service_role_key]
     ADMIN_TOKEN=devtoken
     ```

3. **Service Role Key 확인**
   - Supabase Dashboard → Settings → API
   - `service_role` key 복사
   - Netlify 환경 변수와 일치하는지 확인

---

### 3️⃣ 브라우저 개발자 도구 확인

1. **관리자 페이지 접속**
   - https://api.allsuri.app/admin

2. **개발자 도구 열기**
   - Windows/Linux: `F12` 또는 `Ctrl + Shift + I`
   - Mac: `Cmd + Option + I`

3. **Console 탭 확인**
   - 다음 로그들을 찾아주세요:
     ```
     [PAGE LOAD] DOM이 로드되었습니다
     [loadUsers] 사용자 목록 로딩 시작...
     [API CALL] URL: /api/admin/users
     [API CALL] Token being sent: devtoken
     [loadUsers] 받은 사용자 수: X
     ```
   
   - ❌ 에러가 보이면 에러 메시지를 확인하세요

4. **Network 탭 확인**
   - Network 탭 클릭
   - "🔄 새로고침" 버튼 클릭 (페이지에 추가됨)
   - `users` 요청 찾기
   - 클릭 후 다음 확인:
     - **Status**: 200 OK 인가요?
     - **Response**: 데이터가 있나요?
     - **Headers**: `admin-token: devtoken`이 전송되나요?

---

### 4️⃣ Netlify Functions 로그 확인

1. **Netlify Dashboard**
   - Functions → admin 선택
   - Recent invocations 확인

2. **로그 확인**
   - `/users` 요청이 있나요?
   - 에러 메시지가 있나요?

---

## 📋 체크리스트

- [ ] Supabase에 사용자 데이터가 있음
- [ ] `role = 'business'` 사용자가 있음
- [ ] `businessstatus = 'pending'` 사용자가 있음
- [ ] Netlify 환경 변수 확인됨
- [ ] SUPABASE_SERVICE_ROLE_KEY가 올바름
- [ ] 브라우저 콘솔에 에러 없음
- [ ] Network 탭에서 `/api/admin/users` 요청이 200 OK
- [ ] Response에 데이터가 있음

---

## 🔧 문제 해결

### 문제 1: Supabase에 데이터가 없음
**원인**: 카카오 로그인 후 Supabase 저장 실패

**해결**:
```sql
-- Supabase SQL Editor에서 실행
-- users 테이블 구조 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;
```

필요한 컬럼들:
- `id` (uuid, primary key)
- `name` (text)
- `email` (text)
- `role` (text)
- `businessname` (text)
- `businessstatus` (text)
- `createdat` (timestamp)
- `external_id` (text)
- `provider` (text)

### 문제 2: 401 Unauthorized
**원인**: ADMIN_TOKEN 불일치

**해결**:
- Netlify 환경 변수: `ADMIN_TOKEN=devtoken`
- 재배포 필요할 수 있음

### 문제 3: 404 Not Found
**원인**: Netlify Functions가 배포되지 않음

**해결**:
- Netlify Deploys 탭에서 최신 배포 확인
- 빌드 로그에서 Functions 배포 확인

---

## 🚀 빠른 테스트

다음 명령어로 API를 직접 테스트할 수 있습니다:

```bash
# 사용자 목록 조회
curl -H "admin-token: devtoken" https://api.allsuri.app/api/admin/users

# 대시보드 통계
curl -H "admin-token: devtoken" https://api.allsuri.app/api/admin/dashboard
```

정상이면 JSON 데이터가 반환됩니다.


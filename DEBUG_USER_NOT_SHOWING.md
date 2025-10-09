# 🔍 사업자 프로필 저장 안되는 문제 디버깅 가이드

## 🐛 문제 발견 및 수정

### **발견된 원인: 컬럼명 불일치**

**문제의 코드** (`auth_service.dart` Line 332):
```dart
if (role == 'business') 'businessStatus': 'pending',  // ❌ camelCase
```

**Supabase 테이블 스키마**:
```sql
businessstatus TEXT  -- ✅ lowercase
```

**결과**: Supabase에 `businessStatus` 컬럼이 없어서 업데이트가 무시되거나 실패했습니다.

---

## ✅ 수정 완료

### 1. `updateRole` 함수 수정
```dart
// 수정 전
'businessStatus': 'pending'

// 수정 후
'businessstatus': 'pending'  // ✅ 소문자로 통일
```

### 2. 로깅 강화
이제 다음 정보를 로그에서 확인할 수 있습니다:

```
📝 사업자 프로필 업데이트 시도: ID=bedf63fe-...
   업데이트 데이터: {name: ..., phonenumber: ..., businessname: ..., ...}
✅ Supabase 사업자 프로필 업데이트 성공: bedf63fe-...
   업데이트된 행 수: 1
   업데이트된 데이터: {id: ..., name: ..., role: business, businessstatus: pending, ...}
```

또는 문제가 있는 경우:
```
⚠️  경고: 업데이트는 성공했으나 반환된 데이터 없음 (해당 ID를 찾지 못했을 수 있음)
```

---

## 🧪 **다시 테스트하기**

### **Step 1: 앱 재실행**
```bash
cd /Users/hurmin-ho/Documents/dev/allsuriapp
flutter run
```

### **Step 2: 카카오 로그인**
1. 홈 화면에서 "카카오톡으로 시작하기" 버튼 클릭
2. 로그인 완료 후 사업자 프로필 화면 진입

### **Step 3: 사업자 프로필 입력**
필수 항목:
- ✅ 이름
- ✅ 전화번호
- ✅ 사업자명

### **Step 4: 로그 확인**
"등록" 버튼 클릭 후 **콘솔 로그**에서 다음 확인:

```
✅ Supabase 역할 업데이트 성공: [UUID], role=business, businessstatus=pending
   업데이트된 데이터: {...}

📝 사업자 프로필 업데이트 시도: ID=[UUID]
   업데이트 데이터: {name: ..., phonenumber: ..., businessname: ..., ...}
✅ Supabase 사업자 프로필 업데이트 성공: [UUID]
   업데이트된 행 수: 1  ← 이게 1이어야 합니다!
   업데이트된 데이터: {...}
```

### **Step 5: Admin Page 확인**
1. `https://api.allsuri.app/admin` 접속
2. "사용자 관리" 섹션 확인
3. **브라우저 강제 새로고침**: `Cmd + Shift + R` (Mac) 또는 `Ctrl + Shift + R` (Windows)
4. 방금 등록한 사업자가 보이는지 확인

---

## 🔍 **여전히 안보인다면?**

### **체크리스트**

#### 1. **로그에서 "업데이트된 행 수: 0" 이 나온다면**
→ 해당 UUID가 Supabase에 존재하지 않습니다.

**확인 방법**:
```sql
-- Supabase SQL Editor에서 실행
SELECT * FROM users WHERE id = '[로그에 나온 UUID]';
```

**해결책**:
- 사용자가 처음 생성될 때 UUID가 올바르게 삽입되었는지 확인
- `auth-kakao-login.ts` Netlify Function이 올바르게 동작하는지 확인

#### 2. **로그에 "Supabase 업데이트 건너뜀" 이 나온다면**
→ Supabase 설정이 누락되었거나, UUID 형식이 아닙니다.

**확인 사항**:
```
⚠️  Supabase 업데이트 건너뜀 (supaReady: false, uuidLike: false)
   현재 사용자 ID: kakao:1234567890  ← 이게 UUID가 아님!
```

**해결책**:
- 카카오 로그인 시 백엔드가 UUID를 생성하고 있는지 확인
- `SUPABASE_URL` 및 `SUPABASE_ANON_KEY` 환경 변수가 설정되었는지 확인

#### 3. **로그에 에러가 나온다면**
```
❌ Supabase 동기화 실패(무시하고 로컬 반영): [에러 메시지]
```

→ **에러 메시지를 공유해주세요!**

---

## 📊 **Supabase에서 직접 확인**

### SQL 쿼리로 확인:
```sql
-- 모든 사업자 사용자 확인
SELECT 
  id, 
  name, 
  email, 
  role, 
  businessstatus,
  businessname,
  phonenumber,
  createdat
FROM users
WHERE role = 'business'
ORDER BY createdat DESC
LIMIT 10;
```

### 예상 결과:
| id | name | email | role | businessstatus | businessname |
|----|------|-------|------|----------------|--------------|
| bedf63fe-... | 홍길동 | test@kakao.com | business | pending | 홍길동 설비 |

---

## 🚨 **긴급 대응: Supabase RLS 정책 확인**

만약 데이터는 있는데 Admin Page에서 안보인다면, **RLS(Row Level Security) 정책** 문제일 수 있습니다.

### 확인 방법:
```sql
-- RLS 정책 확인
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'users';
```

### 필요한 정책:
```sql
-- Service role (Netlify Functions)이 모든 데이터 접근 가능
CREATE POLICY "Service role has full access"
ON users FOR ALL TO service_role
USING (true) WITH CHECK (true);
```

---

## 📝 **로그 공유 시 포함해야 할 정보**

문제가 지속되면 다음 로그를 복사해서 공유해주세요:

1. **카카오 로그인 직후**:
   ```
   [API][POST] https://api.allsuri.app/api/auth/kakao/login
   [API][POST] 200 OK
   ✅ Supabase 역할 업데이트 성공: [UUID]
   ```

2. **사업자 프로필 등록 시**:
   ```
   📝 사업자 프로필 업데이트 시도: ID=[UUID]
   업데이트 데이터: {...}
   ✅ Supabase 사업자 프로필 업데이트 성공
   업데이트된 행 수: [숫자]
   ```

3. **Supabase SQL 결과**:
   ```sql
   SELECT * FROM users WHERE id = '[UUID]';
   ```

---

**마지막 업데이트**: 2025-01-09
**수정된 파일**: `lib/services/auth_service.dart`
**주요 변경**: `businessStatus` → `businessstatus` (컬럼명 통일)


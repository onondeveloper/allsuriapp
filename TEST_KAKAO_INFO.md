# 📱 카카오 로그인 정보 수집 테스트

## 🎯 변경 사항

### 1. 카카오에서 수집하는 정보 확장
- **카카오 ID** (`kakao_id`): 카카오 고유 사용자 ID
- **프로필 이미지** (`profile_image`): 프로필 사진 URL
- **전화번호** (`phonenumber`): 카카오에 등록된 전화번호
- **연령대** (`age_range`): 예) 20~29, 30~39 등
- **생일** (`birthday`): MMDD 형식
- **성별** (`gender`): male/female

### 2. Admin 페이지 변경
- **이메일 컬럼** → **카카오 ID 컬럼**으로 대체
- 카카오 ID는 `<code>` 태그로 표시되어 가독성 향상

### 3. 기존 사용자 정보 자동 업데이트
- 로그인 시마다 카카오에서 최신 닉네임과 프로필 이미지 업데이트
- 전화번호는 없을 경우에만 추가 (기존 값 보존)
- 카카오 ID가 없는 기존 사용자는 자동으로 추가

---

## 🚀 테스트 단계

### **단계 1: Supabase 테이블 업데이트**

1. **Supabase Dashboard 접속**
   - https://supabase.com → 프로젝트 선택

2. **SQL Editor 열기**
   - 좌측 메뉴 → SQL Editor

3. **SQL 실행**
   ```bash
   # 로컬에서 파일 확인
   cat database/add_kakao_columns.sql
   ```
   - SQL Editor에 복사 & 붙여넣기 → **RUN** 클릭

4. **결과 확인**
   ```
   ✅ kakao_id 컬럼 추가 완료
   ✅ profile_image 컬럼 추가 완료
   ✅ age_range 컬럼 추가 완료
   ✅ birthday 컬럼 추가 완료
   ✅ gender 컬럼 추가 완료
   ✅ 카카오 로그인 정보 컬럼 추가 완료
   ```

---

### **단계 2: Netlify 배포**

1. **Git에 변경사항 커밋 & 푸시**
   ```bash
   cd /Users/hurmin-ho/Documents/dev/allsuriapp
   git add -A
   git commit -m "✨ 카카오 로그인 정보 확장 수집

   주요 변경사항:
   - 카카오 ID, 프로필 이미지, 연령대, 생일, 성별 수집
   - Admin 페이지: 이메일 → 카카오 ID 컬럼으로 변경
   - 기존 사용자 정보 자동 업데이트 로직 추가
   - Supabase 테이블 스키마 업데이트 SQL 추가"
   git push
   ```

2. **Netlify 배포 확인**
   - https://app.netlify.com → 사이트 선택
   - **Deploys** 탭에서 배포 진행 상황 확인
   - 배포 완료까지 **1-2분** 대기

3. **배포 완료 후 확인**
   ```bash
   # auth-kakao-login 함수 배포 확인
   curl -i https://api.allsuri.app/api/ai/status
   
   # 200 OK 응답 확인
   ```

---

### **단계 3: 카카오 개발자 콘솔 설정 확인**

1. **Kakao Developers 접속**
   - https://developers.kakao.com → 내 애플리케이션

2. **동의 항목 설정 확인**
   - 좌측 메뉴 → **카카오 로그인** → **동의 항목**
   - 다음 항목들이 **선택 동의**로 설정되어 있는지 확인:
     - ✅ 닉네임
     - ✅ 프로필 사진
     - ✅ 카카오계정(이메일)
     - ✅ 전화번호
     - ✅ 연령대
     - ✅ 생일
     - ✅ 성별

   > **참고**: 전화번호, 연령대, 생일, 성별은 **비즈니스 앱**에서만 사용 가능합니다.
   > 일반 앱인 경우 카카오에 비즈니스 승인을 요청해야 합니다.

---

### **단계 4: 앱 테스트**

1. **기존 사용자 로그아웃 (선택)**
   ```bash
   # 앱을 완전히 종료하고 데이터 삭제
   # Settings → Apps → allsuri → Storage → Clear Data
   ```

2. **앱 실행**
   ```bash
   cd /Users/hurmin-ho/Documents/dev/allsuriapp
   
   flutter run \
     --dart-define=KAKAO_NATIVE_APP_KEY=9462c73fdeaba67181aadcc46af6d293 \
     --dart-define=SUPABASE_URL=https://sggwqbfhlzvhfmdbfjwo.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnZ3dxYmZobHp2aGZtZGJmandvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMzk4MTcsImV4cCI6MjA1NjgxNTgxN30.mREJwN5qgnMCh7H8Qtr8Nt2Q5hNJ7ivhXfx22pcdvkI \
     --dart-define=API_BASE_URL=https://api.allsuri.app/api \
     --dart-define=ALLOW_TEST_KAKAO=true
   ```

3. **카카오 로그인 실행**
   - 홈 화면 → **카카오톡으로 빠르게 사업자 시작** 버튼 클릭
   - 카카오톡 앱으로 전환 → 동의 화면에서 **추가 정보 동의** 확인
   - 동의 후 앱으로 복귀

4. **콘솔 로그 확인**
   ```
   📱 카카오 사용자 정보 수집: {
     kakaoId: 4479276246,
     name: 사용자닉네임,
     email: user@example.com,
     hasProfileImage: true,
     hasPhone: true,
     ageRange: 30~39,
     gender: male
   }
   ✅ Supabase 사용자 생성 성공: [UUID]
   ```

---

### **단계 5: Admin 페이지 확인**

1. **Admin 페이지 접속**
   ```bash
   open https://api.allsuri.app/admin
   ```

2. **하드 리프레시 (캐시 제거)**
   - **Mac**: `Cmd + Shift + R`
   - **Windows**: `Ctrl + Shift + R`

3. **사용자 관리 탭 확인**
   - **이메일** 컬럼이 → **카카오 ID** 컬럼으로 변경되었는지 확인
   - 새로 로그인한 사용자의 카카오 ID가 표시되는지 확인
   - 카카오 ID는 `<code>` 스타일로 표시됨 (예: `4479276246`)

4. **사용자 상세 정보 확인**
   - 사용자 **이름**을 클릭하여 상세 모달 열기
   - 다음 정보가 표시되는지 확인:
     - 프로필 이미지
     - 연령대
     - 생일
     - 성별

---

### **단계 6: Supabase 데이터 직접 확인**

1. **Supabase Dashboard 접속**
   - https://supabase.com → 프로젝트 선택

2. **Table Editor 열기**
   - 좌측 메뉴 → Table Editor → `users` 테이블

3. **새 컬럼 확인**
   - `kakao_id`: 카카오 고유 ID (예: `4479276246`)
   - `profile_image`: 프로필 이미지 URL
   - `phonenumber`: 전화번호 (카카오에서 제공한 경우)
   - `age_range`: 연령대 (예: `30~39`)
   - `birthday`: 생일 (예: `0315`)
   - `gender`: 성별 (예: `male`, `female`)

---

## ✅ 테스트 체크리스트

- [ ] Supabase에 새 컬럼들이 추가되었는가?
- [ ] Netlify 배포가 성공적으로 완료되었는가?
- [ ] 카카오 로그인 시 추가 정보 동의 화면이 나타나는가?
- [ ] 앱 콘솔에 카카오 정보 수집 로그가 출력되는가?
- [ ] Admin 페이지의 이메일 컬럼이 카카오 ID로 변경되었는가?
- [ ] 새 사용자의 카카오 ID가 Admin 페이지에 표시되는가?
- [ ] Supabase users 테이블에 카카오 정보가 저장되는가?
- [ ] 기존 사용자가 재로그인 시 정보가 업데이트되는가?

---

## 🔍 디버깅

### 카카오에서 정보를 받지 못하는 경우

**원인**: 카카오 동의 항목 미설정 또는 비즈니스 앱 미승인

**해결**:
1. Kakao Developers → 동의 항목 확인
2. 전화번호, 연령대 등은 **비즈니스 앱**에서만 사용 가능
3. 일반 앱인 경우: 닉네임, 프로필 사진, 이메일만 수집 가능

### Admin 페이지에 카카오 ID가 표시되지 않는 경우

**해결**:
1. 하드 리프레시: `Cmd + Shift + R` (Mac) / `Ctrl + Shift + R` (Windows)
2. Netlify 함수 로그 확인:
   ```bash
   # Netlify Dashboard → Functions → auth-kakao-login → Recent invocations
   ```
3. Supabase 테이블 직접 확인

### Supabase에 데이터가 저장되지 않는 경우

**해결**:
```bash
# 1. Netlify 환경변수 확인
# Netlify Dashboard → Site settings → Environment variables
# - SUPABASE_URL
# - SUPABASE_SERVICE_ROLE_KEY
# - JWT_SECRET

# 2. SQL 스크립트 재실행
# Supabase SQL Editor에서 add_kakao_columns.sql 재실행
```

---

## 📊 활용 방안

수집된 카카오 정보는 다음과 같이 활용할 수 있습니다:

1. **마케팅 타겟팅**
   - 연령대별 맞춤 광고
   - 성별에 따른 서비스 추천

2. **사용자 경험 개선**
   - 프로필 이미지로 친근한 UI
   - 생일 축하 메시지 자동 발송

3. **고객 분석**
   - 연령대별 서비스 이용 패턴 분석
   - 지역별 사용자 통계

4. **자동화**
   - 전화번호로 SMS 알림 발송
   - 카카오톡 메시지 발송 (추후 구현)

---

## 🎉 완료!

모든 테스트가 통과하면 카카오 로그인 정보 수집 기능이 정상적으로 작동하는 것입니다! 🚀


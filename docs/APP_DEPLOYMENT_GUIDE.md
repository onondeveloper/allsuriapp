# 📱 올수리 앱 배포 가이드

## 🎯 배포 프로세스 개요

**중요**: Git push만으로는 앱이 자동 배포되지 않습니다!
매번 새로운 AAB 파일을 빌드하고 Google Play Console에 수동으로 업로드해야 합니다.

```
코드 수정 → Git Push → AAB 빌드 → Play Console 업로드 → 배포
```

---

## 📋 전체 배포 프로세스

### 1️⃣ 버전 번호 증가

**파일**: `pubspec.yaml`

```yaml
# 현재
version: 1.0.0+11

# 다음 배포 시
version: 1.0.0+12  # 빌드 번호 1씩 증가
```

**버전 규칙**:
- **1.0.0**: 버전 이름 (사용자에게 표시)
  - 메이저 업데이트 시: 2.0.0
  - 마이너 업데이트 시: 1.1.0
  - 버그 수정 시: 1.0.1
- **+12**: 빌드 번호 (내부 버전 코드, 항상 증가)

### 2️⃣ Git Commit & Push

```bash
git add -A
git commit -m "feat: 복수 오더 입찰 기능 추가 (v1.0.0+12)"
git push origin main
```

### 3️⃣ AAB 파일 빌드

**터미널에서 실행**:

```bash
# 프로덕션 빌드 (Play Store 배포용)
./build_aab.sh prod

# 또는 수동 빌드
flutter build appbundle --dart-define-from-file=dart_defines.json
```

**빌드 결과**:
```
✅ AAB 빌드 완료!
📁 파일 위치: build/app/outputs/bundle/release/app-release.aab
📏 파일 크기: 약 25-30MB
```

### 4️⃣ Google Play Console 업로드

#### **A. Play Console 접속**
1. https://play.google.com/console 로그인
2. 앱 선택: **올수리**

#### **B. 내부 테스트 트랙 업로드**
```
Play Console
  → 출시 → 테스트 → 비공개 테스트 (또는 내부 테스트)
  → 새 버전 만들기
  → AAB 업로드
  → 버전 이름: 1.0.0 (12)
  → 출시 노트 작성
  → 검토 → 출시
```

#### **C. 출시 노트 예시**

```
버전 1.0.0 (12)

🎉 새로운 기능
- 복수 오더에 동시 입찰 가능
- 입찰한 오더 개수 대시보드 표시

🔧 개선 사항
- 공사 완료 시 실시간 알림 개선
- 채팅방 생성 로직 개선

🐛 버그 수정
- RLS 정책 충돌 문제 해결
- 리뷰 버튼 표시 조건 개선
```

### 5️⃣ 배포 승인 대기

- **내부 테스트**: 즉시 배포 (몇 분 내)
- **비공개 테스트**: 검토 후 배포 (수 시간)
- **프로덕션**: Google 검토 필요 (1-3일)

---

## ⚡ 빠른 배포 가이드

### **옵션 A: 스크립트 사용 (권장)**

```bash
# 1. 버전 번호 수동 증가 (pubspec.yaml)
# version: 1.0.0+12

# 2. AAB 빌드
./build_aab.sh prod

# 3. 생성된 파일 확인
open build/app/outputs/bundle/release/

# 4. Play Console에 업로드
```

### **옵션 B: 수동 빌드**

```bash
# 1. 의존성 업데이트
flutter pub get

# 2. 클린 빌드
flutter clean
flutter build appbundle --release

# 3. 파일 확인
ls -lh build/app/outputs/bundle/release/app-release.aab
```

---

## 🧪 배포 전 체크리스트

- [ ] 버전 번호 증가 (`pubspec.yaml`)
- [ ] 모든 변경사항 Git commit
- [ ] Supabase SQL 스크립트 실행 (필요시)
- [ ] 로컬에서 앱 테스트 (디버그 모드)
- [ ] AAB 빌드 성공
- [ ] AAB 파일 크기 확인 (< 50MB)
- [ ] Play Console에 업로드
- [ ] 출시 노트 작성
- [ ] 배포 승인 대기

---

## 📊 배포 주기 권장사항

| 배포 타입 | 주기 | 용도 |
|-----------|------|------|
| **내부 테스트** | 매일 | 개발 중 기능 테스트 |
| **비공개 테스트** | 주 1-2회 | 핵심 기능 검증 |
| **프로덕션** | 2주 1회 | 안정화된 버전 배포 |

---

## 🔧 Supabase 변경사항 배포

**중요**: 데이터베이스/백엔드 변경은 앱 배포와 별도!

### **Step 1: SQL 스크립트 실행**

```sql
-- Supabase SQL Editor에서 실행
-- 예: database/fix_complete_job_rls.sql
```

### **Step 2: 즉시 적용**

- ✅ RLS 정책 변경: **즉시 적용**
- ✅ 테이블 스키마 변경: **즉시 적용**
- ✅ Edge Function 배포: **즉시 적용**

**앱 재배포 불필요** - 기존 앱도 새 정책 사용

---

## 🐛 트러블슈팅

### **문제: AAB 빌드 실패**

**해결:**
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### **문제: 서명 에러**

**확인:**
```bash
# key.properties 파일 확인
cat android/key.properties

# keystore 파일 존재 확인
ls -l android/upload-keystore.jks
```

### **문제: Play Console 업로드 거부**

**원인:**
- 빌드 번호가 이전 버전보다 작음
- 서명 키가 다름

**해결:**
- `pubspec.yaml`에서 빌드 번호 증가
- 올바른 keystore 사용 확인

---

## 📈 버전 히스토리 추적

### **Git Tag 사용**

```bash
# 새 버전 태그 생성
git tag -a v1.0.0+12 -m "Release: 복수 오더 입찰 기능"
git push origin v1.0.0+12

# 태그 목록 보기
git tag -l
```

### **버전 로그 기록**

**파일**: `CHANGELOG.md` (생성 권장)

```markdown
# 버전 히스토리

## [1.0.0+12] - 2025-11-27
### Added
- 복수 오더 동시 입찰 기능
- 입찰한 오더 개수 대시보드 표시

### Fixed
- RLS 정책 충돌 문제
- 공사 완료 버튼 작동 이슈

## [1.0.0+11] - 2025-11-26
...
```

---

## 🚀 자동화 (향후 개선)

### **GitHub Actions 자동 빌드**

```yaml
# .github/workflows/build.yml
name: Build AAB
on:
  push:
    tags:
      - 'v*'
      
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build appbundle
      - uses: actions/upload-artifact@v3
        with:
          name: app-release.aab
          path: build/app/outputs/bundle/release/app-release.aab
```

### **Fastlane 자동 배포**

```ruby
# fastlane/Fastfile
lane :deploy_internal do
  gradle(task: "bundleRelease")
  upload_to_play_store(
    track: 'internal',
    aab: 'build/app/outputs/bundle/release/app-release.aab'
  )
end
```

---

## 📞 지원

배포 중 문제가 발생하면:
1. `database/FIX_CRITICAL_ERRORS.md` 참조
2. Play Console 오류 로그 확인
3. Flutter 로그 확인: `flutter logs`

---

## ✅ 요약

| 작업 | 자동 배포 | 수동 작업 |
|------|-----------|-----------|
| **코드 변경** | ❌ | Git push |
| **Supabase SQL** | ✅ 즉시 적용 | SQL 실행 |
| **Flutter 앱** | ❌ | AAB 빌드 + 업로드 |
| **Netlify 함수** | ✅ Git push 시 | - |
| **백엔드 API** | ✅ Git push 시 | - |

**핵심**: Flutter 앱만 수동 배포 필요, 나머지는 자동!


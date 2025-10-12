# 올수리 앱 개발 가이드

## 🚀 빠른 시작

### 1. 환경 변수 설정

프로젝트 루트에 `dart_defines.json` 파일을 생성하세요:

```bash
cp dart_defines.example.json dart_defines.json
```

그리고 실제 값으로 수정:

```json
{
  "KAKAO_NATIVE_APP_KEY": "실제_카카오_앱_키",
  "API_BASE_URL": "https://api.allsuri.app/api",
  "SUPABASE_URL": "실제_Supabase_URL",
  "SUPABASE_ANON_KEY": "실제_Supabase_Anon_Key"
}
```

### 2. 앱 실행

#### 방법 1: VS Code (가장 간단) ⭐ 권장

1. VS Code에서 `F5` 또는 `Cmd+Shift+D` → 디버그 패널 열기
2. "올수리 (Production)" 또는 "올수리 (Development)" 선택
3. 실행 버튼 클릭

#### 방법 2: Shell 스크립트

```bash
# 프로덕션 환경
./run_app.sh prod

# 개발 환경 (localhost API)
./run_app.sh dev
```

#### 방법 3: Flutter CLI

```bash
# 프로덕션 환경
flutter run --dart-define-from-file=dart_defines.json

# 개발 환경
flutter run --dart-define-from-file=dart_defines.dev.json
```

---

## 📦 빌드

### APK 빌드

```bash
# 프로덕션 APK
./build_apk.sh prod

# 개발 APK
./build_apk.sh dev
```

또는:

```bash
flutter build apk --dart-define-from-file=dart_defines.json
```

### iOS 빌드

```bash
flutter build ios --dart-define-from-file=dart_defines.json
```

---

## 🌍 환경 구성

### Production (`dart_defines.json`)
- API: `https://api.allsuri.app/api`
- 실제 Kakao 로그인
- 프로덕션 Supabase

### Development (`dart_defines.dev.json`)
- API: `http://localhost:3001/api`
- 테스트 Kakao 로그인 활성화
- 개발용 Supabase

---

## 🔧 Hot Reload / Hot Restart

앱 실행 중에:
- `r` : Hot Reload (빠른 새로고침)
- `R` : Hot Restart (앱 재시작)
- `q` : 앱 종료

---

## 📱 디바이스 선택

```bash
# 연결된 디바이스 확인
flutter devices

# 특정 디바이스로 실행
flutter run -d device_id --dart-define-from-file=dart_defines.json
```

---

## 🐛 디버깅

### VS Code 디버그 포인트
1. 코드에 중단점 설정 (줄 번호 왼쪽 클릭)
2. F5로 디버그 모드 실행
3. 변수 값 확인, 단계별 실행 가능

### 로그 확인
```bash
# Android
adb logcat | grep flutter

# 모든 로그
flutter logs
```

---

## 📂 파일 구조

```
.
├── dart_defines.json              # 환경 변수 (Production)
├── dart_defines.dev.json          # 환경 변수 (Development)
├── dart_defines.example.json      # 환경 변수 예제
├── run_app.sh                     # 앱 실행 스크립트
├── build_apk.sh                   # APK 빌드 스크립트
└── .vscode/
    └── launch.json                # VS Code 디버그 설정
```

---

## ⚠️ 주의사항

1. **`dart_defines.json`은 절대 Git에 커밋하지 마세요!**
   - 이미 `.gitignore`에 포함되어 있습니다
   - 민감한 정보(API 키, 토큰 등)가 포함되어 있습니다

2. **팀원에게 공유할 때**
   - `dart_defines.example.json`을 복사하여 실제 값 입력
   - 또는 안전한 방법(1Password, Vault 등)으로 공유

3. **CI/CD 환경**
   - GitHub Secrets 또는 환경 변수로 설정
   - 빌드 시 `dart_defines.json` 동적 생성

---

## 🆘 문제 해결

### "dart_defines.json not found" 에러
```bash
cp dart_defines.example.json dart_defines.json
# 그리고 실제 값으로 수정
```

### Shell 스크립트 실행 권한 에러
```bash
chmod +x run_app.sh build_apk.sh
```

### Kakao SDK 에러
- `KAKAO_NATIVE_APP_KEY`가 올바른지 확인
- Kakao Developers Console에서 앱 설정 확인

### API 연결 에러
- `API_BASE_URL`이 올바른지 확인
- 백엔드 서버가 실행 중인지 확인
- 개발 환경: `http://localhost:3001/api`
- 프로덕션: `https://api.allsuri.app/api`

---

## 📖 더 알아보기

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Dart 공식 문서](https://dart.dev/guides)
- [Kakao Flutter SDK](https://developers.kakao.com/docs/latest/ko/flutter-sdk/getting-started)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)


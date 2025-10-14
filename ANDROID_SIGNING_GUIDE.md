# 🔐 Android 앱 서명 가이드

## 📋 개요

이 문서는 올수리 앱의 Android 릴리즈 빌드 서명 설정 방법을 설명합니다.

## 🔑 Keystore 정보

### 생성된 Keystore
- **파일**: `android/upload-keystore.jks`
- **별칭 (Alias)**: `allsuri`
- **비밀번호**: `allsuri2024!`
- **유효기간**: 10,000일 (약 27년)
- **알고리즘**: RSA 2048-bit

⚠️ **중요**: 이 Keystore 파일과 비밀번호는 절대 분실하지 마세요! 
- 분실 시 기존 앱을 업데이트할 수 없습니다.
- 안전한 곳에 백업하세요 (예: 암호화된 클라우드 저장소, 비밀번호 관리자)

## 📁 파일 구조

```
android/
├── upload-keystore.jks     # Keystore 파일 (절대 Git에 커밋하지 마세요!)
└── key.properties          # Keystore 설정 (절대 Git에 커밋하지 마세요!)
```

## 🚀 AAB 빌드 방법

### 방법 1: 스크립트 사용 (권장)

```bash
# 프로덕션 빌드
./build_aab.sh prod

# 빌드 번호 지정
./build_aab.sh prod 2

# 개발 빌드
./build_aab.sh dev
```

### 방법 2: Flutter 명령어 직접 사용

```bash
# 기본 빌드
flutter build appbundle --dart-define-from-file=dart_defines.json

# 빌드 번호 및 버전 지정
flutter build appbundle \
  --dart-define-from-file=dart_defines.json \
  --build-name=1.0.0 \
  --build-number=1

# 빌드 정보 확인
flutter build appbundle --verbose --dart-define-from-file=dart_defines.json
```

## 📤 Google Play Console 업로드

1. **AAB 파일 위치 확인**
   ```bash
   # 빌드된 파일 위치
   build/app/outputs/bundle/release/app-release.aab
   ```

2. **Google Play Console 접속**
   - https://play.google.com/console 접속
   - 올수리 앱 선택

3. **프로덕션 트랙으로 이동**
   - 좌측 메뉴: `프로덕션` 또는 `테스트` 선택
   - `새 버전 만들기` 클릭

4. **AAB 업로드**
   - `app-release.aab` 파일을 드래그 앤 드롭
   - 또는 `업로드` 버튼 클릭하여 파일 선택

5. **출시 노트 작성**
   - 변경 사항 입력
   - 모든 지원 언어에 대해 작성

6. **검토 및 출시**
   - `검토` 버튼 클릭
   - 모든 정보 확인 후 `프로덕션으로 출시` 클릭

## 🔄 버전 관리

### pubspec.yaml에서 버전 업데이트

```yaml
version: 1.0.0+1  # format: 버전명+빌드번호
```

- **버전명 (version name)**: 사용자에게 표시되는 버전 (예: 1.0.0)
- **빌드 번호 (version code)**: 내부 버전 번호 (정수, 매 빌드마다 증가)

### 버전 업데이트 예시

```yaml
# 첫 출시
version: 1.0.0+1

# 버그 수정
version: 1.0.1+2

# 마이너 업데이트
version: 1.1.0+3

# 메이저 업데이트
version: 2.0.0+4
```

## 🛡️ 보안 주의사항

### ❌ 절대 하지 말아야 할 것

1. **Keystore 파일을 Git에 커밋하지 마세요**
   - `.gitignore`에 이미 추가되어 있습니다
   - 실수로 커밋했다면 즉시 Git 히스토리에서 제거하고 새 Keystore 생성

2. **비밀번호를 코드에 하드코딩하지 마세요**
   - `key.properties` 파일 사용 (Git에 커밋되지 않음)
   - 환경 변수 사용 권장

3. **공개 저장소에 업로드하지 마세요**
   - 프라이빗 저장소만 사용

### ✅ 해야 할 것

1. **안전한 곳에 백업**
   - Keystore 파일: `android/upload-keystore.jks`
   - 비밀번호 정보: `android/key.properties`
   - 추천: 1Password, LastPass 등 비밀번호 관리자

2. **팀원과 공유 방법**
   - 암호화된 메신저 사용 (Signal, Telegram 비밀 채팅)
   - 비밀번호 관리 도구의 공유 기능 사용
   - 절대 이메일이나 공개 채팅으로 전송하지 마세요

## 🔧 문제 해결

### 빌드 실패: Keystore not found

**오류 메시지:**
```
Keystore file not found for signing config 'release'
```

**해결 방법:**
1. `android/upload-keystore.jks` 파일 존재 확인
2. `android/key.properties` 파일의 경로 확인
3. 경로가 올바른지 확인 (`storeFile=../upload-keystore.jks`)

### 비밀번호 오류

**오류 메시지:**
```
Keystore was tampered with, or password was incorrect
```

**해결 방법:**
1. `android/key.properties`의 비밀번호 확인
2. Keystore가 손상되지 않았는지 확인
3. 필요시 새 Keystore 생성 (단, 기존 앱은 업데이트 불가)

### 서명 충돌

**오류 메시지:**
```
Upload failed: You uploaded an APK that is signed with a different certificate
```

**해결 방법:**
- Google Play Console에 처음 업로드한 APK/AAB의 Keystore와 동일한 Keystore를 사용해야 합니다.
- Keystore를 분실했다면 새로운 패키지명으로 앱을 재출시해야 합니다.

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. 이 가이드의 문제 해결 섹션
2. Flutter 공식 문서: https://docs.flutter.dev/deployment/android
3. Google Play Console 도움말

---

**마지막 업데이트**: 2025-10-13


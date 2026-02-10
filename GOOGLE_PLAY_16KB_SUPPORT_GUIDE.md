# Google Play 16KB 페이지 크기 지원 가이드

## 📋 개요

2025년 11월 1일부터 Google Play에 제출되는 모든 앱은 Android 15+ 기기의 **16KB 메모리 페이지 크기**를 지원해야 합니다.

**참고**: [Google 공식 발표](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)

---

## ✅ 올수리 앱에 적용된 설정

### 1. Android Gradle Plugin & Gradle 버전
- **AGP**: 8.3.2 (`android/build.gradle`)
- **Gradle**: 8.4 (`android/gradle/wrapper/gradle-wrapper.properties`)
- **Kotlin**: 1.9.24 (`android/settings.gradle` & `android/build.gradle`)

### 2. 컴파일 SDK & 타겟
- **compileSdk**: 36 (`android/app/build.gradle`)
- **targetSdk**: Flutter 기본값 (34+)
- **NDK Version**: 27.0.12077973 (16KB 완전 지원)

### 3. 16KB 페이지 정렬 플래그
#### `android/gradle.properties`
```properties
android.experimental.enable16KbPageSize=true
```

#### `android/app/build.gradle`
```gradle
defaultConfig {
    // ...
    ndk {
        abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
    }
    externalNativeBuild {
        cmake {
            arguments "-DANDROID_MAX_PAGE_SIZE=16384"
            cppFlags "-Wl,-z,max-page-size=16384"
        }
    }
}
```

### 4. Java & Kotlin 호환성
- **Java Version**: 17 (`android/app/build.gradle`)
- **Kotlin JVM Target**: 17

### 5. 권한 설정 (사진/동영상 접근 권한 제거)
#### `android/app/src/main/AndroidManifest.xml`
```xml
<!-- 의존성 패키지가 추가한 미디어 권한 명시적 제거 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove" />
```

---

## 🚀 빌드 절차

### 방법 1: 스크립트 사용 (권장)
```bash
# 1. 완전한 클린 빌드
flutter clean
rm -rf build android/build android/app/build

# 2. 의존성 재설치
flutter pub get

# 3. AAB 빌드 (버전 코드는 이전보다 높아야 함)
./build_aab.sh prod 26
```

### 방법 2: 수동 빌드
```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

---

## 🔍 호환성 확인 방법

### Play Console에서 확인
1. Google Play Console 접속
2. **출시 관리 > 앱 번들 탐색기**로 이동
3. 업로드한 AAB 버전 선택
4. "16KB 호환성" 섹션 확인

### 로컬 테스트 (선택사항)
Android 15 에뮬레이터에서 앱을 실행하여 직접 확인:
```bash
# 16KB 환경 에뮬레이터 실행
flutter run --release
```

---

## 🐛 문제 해결

### 여전히 16KB 오류 발생 시

#### 1. Gradle 캐시 완전 삭제
```bash
flutter clean
rm -rf ~/.gradle/caches
rm -rf android/.gradle
cd android
./gradlew clean
cd ..
flutter build appbundle --release
```

#### 2. 특정 패키지 문제 확인
`pubspec.yaml`의 다음 패키지들이 16KB 호환 버전인지 확인:
- `kakao_flutter_sdk`: 1.9.5+ (✅ 현재: 1.9.5)
- `firebase_core`: 3.4.0+ (✅ 현재: 3.4.0)
- `image_picker`: 1.0.0+ (✅ 현재: 1.0.4)

#### 3. Flutter SDK 업그레이드 (최후의 수단)
만약 모든 조치 후에도 오류가 계속되면, Flutter SDK 자체를 16KB를 완전히 지원하는 버전으로 업그레이드 필요:
```bash
flutter upgrade
```

---

## 📊 성능 향상 기대효과

16KB 지원으로 얻을 수 있는 이점 (Google 공식 발표 기준):
- ⚡ **앱 실행 속도**: 3-30% 개선
- 🔋 **배터리 사용**: 평균 4.5% 개선
- 📷 **카메라 시작**: 4.5-6.6% 빠름
- 🚀 **시스템 부팅**: 약 8% 빠름

---

## 📝 체크리스트

빌드 전 확인사항:
- [ ] `pubspec.yaml`의 버전 코드가 이전 업로드 버전보다 높음
- [ ] `android/app/build.gradle`에 NDK 설정 존재
- [ ] `android/gradle.properties`에 16KB 플래그 존재
- [ ] `flutter clean` 실행 후 빌드
- [ ] AAB 파일 생성 확인
- [ ] Play Console 업로드 후 24-48시간 내 검토 상태 확인

---

**마지막 업데이트**: 2025-01-07  
**문서 버전**: 1.0  
**참고 자료**: [Android Developers Blog - 16KB Support](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)

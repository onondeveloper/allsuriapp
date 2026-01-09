# 카카오톡 공유 문제 해결 가이드

## 🐛 문제: 카카오톡이 열리지 않음

### 원인
Android 11 이상에서는 **패키지 가시성(Package Visibility)** 정책으로 인해, 다른 앱(카카오톡)을 실행하려면 `AndroidManifest.xml`에 명시적으로 선언해야 합니다.

### ✅ 해결 방법

#### 1. AndroidManifest.xml 수정 (완료)

`android/app/src/main/AndroidManifest.xml` 파일의 `<queries>` 섹션에 카카오톡 패키지 추가:

```xml
<queries>
    <!-- 기존 코드 -->
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT" />
        <data android:mimeType="text/plain" />
    </intent>
    
    <!-- ✅ 카카오톡 패키지 추가 (로그인 + 공유) -->
    <package android:name="com.kakao.talk" />
    
    <package android:name="com.ononcompany.allsuriapp" />
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="kakaolink" />
    </intent>
</queries>
```

#### 2. 앱 재빌드 필수

AndroidManifest.xml 변경 후에는 **반드시 앱을 재빌드**해야 합니다:

```bash
# Hot Reload로는 적용 안 됨!
flutter clean
flutter run

# 또는 릴리즈 빌드
flutter build apk --release
```

#### 3. 디버깅 로그 확인

오더 생성 후 공유 버튼 클릭 시 다음 로그가 출력되어야 합니다:

```
🔍 [CreateJobScreen] 카카오톡 공유 버튼 클릭
   orderId: xxx-xxx-xxx
   title: 테스트 오더
🔍 [KakaoShare] shareOrder 시작
   orderId: xxx-xxx-xxx
   title: 테스트 오더
   region: 서울시
   category: 일반
🔍 [KakaoShare] 카카오톡 설치 여부 확인 중...
   카카오톡 설치: ✅ 설치됨
🔍 [KakaoShare] 카카오톡 공유 시작...
✅ 오더 카카오톡 공유 성공
✅ [CreateJobScreen] 카카오톡 공유 성공
```

## 🔍 문제 진단 체크리스트

### 1단계: AndroidManifest.xml 확인
- [ ] `<package android:name="com.kakao.talk" />` 추가되었는가?
- [ ] `<queries>` 태그가 `<application>` 태그 밖에 있는가?

### 2단계: 카카오톡 설치 확인
- [ ] 기기에 카카오톡이 설치되어 있는가?
- [ ] 카카오톡 버전이 최신인가?

### 3단계: 앱 재빌드 확인
- [ ] `flutter clean` 실행했는가?
- [ ] 앱을 완전히 종료하고 재실행했는가?
- [ ] Hot Reload가 아닌 전체 재빌드를 했는가?

### 4단계: 로그 확인
- [ ] `🔍 [KakaoShare]` 로그가 출력되는가?
- [ ] "카카오톡 설치: ✅ 설치됨" 메시지가 보이는가?
- [ ] 에러 메시지가 있는가?

## 🚨 일반적인 오류 및 해결

### 오류 1: "카카오톡 설치: ❌ 미설치"
**원인**: AndroidManifest.xml에 `com.kakao.talk` 패키지 선언 누락

**해결**:
1. AndroidManifest.xml에 `<package android:name="com.kakao.talk" />` 추가
2. `flutter clean && flutter run` 실행

### 오류 2: 공유 다이얼로그가 표시되지 않음
**원인**: 오더 등록 플로우에서 다이얼로그 호출 누락

**확인**:
```dart
// create_job_screen.dart의 _showPostCreateOptions 메서드 내부
await _showKakaoShareDialog(
  parentContext,
  orderId: result['id']?.toString() ?? '',
  title: title,
  region: region ?? '',
  category: category,
  budget: budget,
  imageUrl: _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : null,
  description: description,
);
```

### 오류 3: "PlatformException"
**원인**: 카카오 SDK 초기화 문제

**확인**:
1. `dart_defines.json`에 `KAKAO_NATIVE_APP_KEY` 설정 확인
2. `main.dart`에서 SDK 초기화 확인:
```dart
final kakaoKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
if (kakaoKey.isNotEmpty) {
  kakao.KakaoSdk.init(nativeAppKey: kakaoKey);
}
```

### 오류 4: 웹 브라우저가 열림 (카카오톡 앱이 안 열림)
**원인**: 카카오톡이 설치되지 않았거나, 패키지 쿼리 설정 누락

**해결**:
1. 카카오톡 설치 확인
2. AndroidManifest.xml 확인
3. 앱 재빌드

## 📱 테스트 방법

### 정상 동작 시나리오

1. **오더 생성**
   - 사업자 로그인
   - "공사 만들기" 진입
   - 정보 입력 (제목, 지역, 카테고리, 예산, 사진)
   - "공사 등록" 클릭

2. **오더로 올리기**
   - "오더로 올리기" 선택
   - 오더 등록 성공

3. **카카오톡 공유 다이얼로그**
   - 자동으로 다이얼로그 표시
   - 오더 정보 미리보기 확인
   - "공유하기" 버튼 클릭

4. **카카오톡 앱 실행**
   - 카카오톡 앱이 자동으로 열림
   - 공유 대상 선택 화면 표시
   - 단체방 선택 후 전송

5. **확인**
   - 녹색 스낵바 "✅ 카카오톡 공유가 시작되었습니다" 표시
   - 오더 마켓플레이스로 이동

## 🔧 고급 디버깅

### 1. ADB 로그 확인

```bash
# 카카오톡 관련 로그만 필터링
adb logcat | grep -i "kakao\|share"

# Flutter 로그만 필터링
adb logcat | grep "flutter"
```

### 2. 카카오톡 앱 Intent 확인

```bash
# 카카오톡 패키지 정보 확인
adb shell pm list packages | grep kakao

# 출력 예시:
# package:com.kakao.talk
```

### 3. 패키지 가시성 확인

```bash
# 앱이 카카오톡을 볼 수 있는지 확인
adb shell dumpsys package com.ononcompany.allsuriapp | grep "com.kakao.talk"
```

## 📚 참고 자료

- [Android 11 패키지 가시성](https://developer.android.com/training/package-visibility)
- [Kakao SDK 공유 가이드](https://developers.kakao.com/docs/latest/ko/kakaotalk-share/android)
- [Flutter 카카오 SDK](https://pub.dev/packages/kakao_flutter_sdk_share)

## 💡 추가 팁

### Hot Reload 제한사항
- AndroidManifest.xml 변경은 Hot Reload로 적용 안 됨
- 반드시 `flutter run` 또는 `flutter build` 필요

### 릴리즈 빌드 시
```bash
# AAB 빌드
flutter build appbundle --release

# APK 빌드
flutter build apk --release
```

### 카카오톡 미설치 시 대응
- 웹 브라우저로 자동 대체
- 사용자에게 카카오톡 설치 안내 가능

---

**마지막 업데이트**: 2025-01-06  
**문제 해결 완료**: AndroidManifest.xml에 `com.kakao.talk` 패키지 추가


# 카카오 로그인 배포 설정 가이드

앱스토어에 배포한 앱에서 카카오 로그인이 작동하지 않는 이유와 해결 방법을 설명합니다.

## 🔴 문제 원인

개발 중에는 **Debug 키 해시**로 카카오 로그인이 작동하지만, 
Play Store에 배포한 앱은 **Release 키 해시**를 사용하기 때문에 
카카오 개발자 콘솔에 Release 키 해시를 등록하지 않으면 로그인이 실패합니다.

## ✅ 해결 방법

### 1. 키 해시 확인

프로젝트 루트에서 다음 명령어를 실행하세요:

```bash
./get_kakao_key_hash.sh
```

출력된 결과에서 **Release 키 해시**를 복사하세요:

```
✅ Release 키 해시 (이것을 카카오 개발자 콘솔에 등록하세요!):
zNb2GVsO4wQ8B9y3IFPGoaxi2r0=
```

### 2. 카카오 개발자 콘솔 설정

#### Step 1: 카카오 개발자 콘솔 접속
1. https://developers.kakao.com 접속
2. 로그인 후 **내 애플리케이션** 클릭
3. **올수리** 애플리케이션 선택

#### Step 2: Android 플랫폼 설정
1. 좌측 메뉴에서 **플랫폼** 클릭
2. **Android 플랫폼 등록** 또는 기존 Android 설정 **수정** 클릭

#### Step 3: 설정 입력
다음 정보를 입력/확인하세요:

- **패키지명**: `com.ononcompany.allsuri`
- **마켓 URL**: Play Store URL (배포 후 입력)
- **키 해시**: 
  ```
  tpsjWyfccHas3NiOWup11jF7lTQ=
  zNb2GVsO4wQ8B9y3IFPGoaxi2r0=
  ```
  
  ⚠️ **중요**: 
  - 첫 번째 줄은 Debug 키 해시 (개발용)
  - 두 번째 줄은 Release 키 해시 (배포용)
  - 둘 다 등록해야 개발과 배포 모두 작동합니다!

#### Step 4: 저장 및 확인
1. **저장** 버튼 클릭
2. 플랫폼 목록에서 Android가 제대로 등록되었는지 확인

### 3. 앱 재배포

이미 배포한 앱이라면:
1. 카카오 콘솔 설정 완료 후 **즉시 적용**됩니다 (앱 재배포 불필요)
2. 사용자가 앱을 재설치할 필요 없이 바로 카카오 로그인이 작동합니다

새로 배포하는 경우:
1. 버전 코드를 증가시키고 (`pubspec.yaml`)
2. Release AAB를 새로 빌드:
   ```bash
   ./build_aab.sh prod
   ```
3. Play Console에 업로드

## 🔍 추가 확인 사항

### Android Manifest 확인

`android/app/src/main/AndroidManifest.xml`에 다음이 있는지 확인:

```xml
<activity
    android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:host="oauth" android:scheme="kakao9462c73fdeaba67181aadcc46af6d293" />
    </intent-filter>
</activity>
```

### 카카오 Native App Key 확인

카카오 개발자 콘솔에서:
1. **앱 설정** > **요약 정보**
2. **앱 키** > **Native 앱 키** 확인
3. Native 앱 키가 `9462c73fdeaba67181aadcc46af6d293`인지 확인

### Flutter 코드 확인

`main.dart`에서 카카오 SDK 초기화 확인:

```dart
KakaoSdk.init(nativeAppKey: '9462c73fdeaba67181aadcc46af6d293');
```

## 🧪 테스트 방법

### 로컬 테스트 (Release 빌드)
```bash
flutter run --release \
  --dart-define=KAKAO_NATIVE_APP_KEY='9462c73fdeaba67181aadcc46af6d293' \
  --dart-define=API_BASE_URL='https://api.allsuri.app' \
  --dart-define=SUPABASE_URL='https://iiunvogtqssxaxdnhqaj.supabase.co' \
  --dart-define=SUPABASE_ANON_KEY='...'
```

### Play Store 테스트
1. Internal Testing 트랙에 업로드
2. 테스터로 등록된 계정으로 다운로드
3. 카카오 로그인 테스트

## ❗ 문제 해결

### 여전히 로그인이 안 되는 경우

1. **카카오 개발자 콘솔 재확인**
   - 패키지명이 정확한지 (`com.ononcompany.allsuri`)
   - Release 키 해시가 등록되었는지
   - 설정 저장을 눌렀는지

2. **앱 서명 확인**
   - Play Console > 앱 무결성 > 앱 서명
   - "Google에서 관리하는 앱 서명 키" 사용 시
   - Play Console에서 제공하는 SHA-1을 Base64로 변환하여 추가 등록 필요

3. **로그 확인**
   ```bash
   adb logcat | grep -i kakao
   ```
   
4. **카카오톡 설치 확인**
   - 기기에 카카오톡이 설치되어 있어야 합니다
   - 카카오톡이 없으면 웹 로그인으로 전환됩니다

## 📋 체크리스트

배포 전 확인:

- [ ] Release 키 해시를 카카오 개발자 콘솔에 등록
- [ ] Debug 키 해시도 함께 등록 (개발용)
- [ ] 패키지명 확인: `com.ononcompany.allsuri`
- [ ] Native 앱 키 확인: `9462c73fdeaba67181aadcc46af6d293`
- [ ] AndroidManifest.xml의 Kakao scheme 확인
- [ ] Release 빌드로 로컬 테스트 완료
- [ ] Internal Testing으로 실제 배포 테스트 완료

## 🔗 참고 자료

- [카카오 로그인 - Android 설정](https://developers.kakao.com/docs/latest/ko/kakaologin/android)
- [Flutter Kakao Login Plugin](https://pub.dev/packages/kakao_flutter_sdk)
- [Play Store 앱 서명](https://support.google.com/googleplay/android-developer/answer/9842756)

---

**중요**: 이 설정은 앱스토어 배포 시 한 번만 하면 됩니다. 
앱을 업데이트할 때는 동일한 키스토어를 사용하는 한 추가 설정이 필요 없습니다.


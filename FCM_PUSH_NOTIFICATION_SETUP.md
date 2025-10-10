# Firebase Cloud Messaging (FCM) 푸시 알림 설정 가이드

## 📋 개요
이 프로젝트에 실시간 푸시 알림 기능이 추가되었습니다. 사업자 승인/거절 외에도 다른 기능에서도 쉽게 사용할 수 있습니다.

## ✅ 완료된 작업

### 1. Flutter (앱)
- ✅ `firebase_core`, `firebase_messaging`, `flutter_local_notifications` 패키지 추가
- ✅ `FCMService` 클래스 구현 (`lib/services/fcm_service.dart`)
- ✅ `main.dart`에서 FCM 초기화
- ✅ `AuthService`에서 로그인 시 FCM 토큰 자동 저장
- ✅ `AuthService`에서 로그아웃 시 FCM 토큰 자동 삭제
- ✅ Android `AndroidManifest.xml` FCM 설정 추가
- ✅ iOS `Info.plist` FCM 설정 추가

### 2. Backend (서버)
- ✅ Firebase Admin SDK 초기화 (`backend/src/services/fcm_service.js`)
- ✅ 푸시 알림 전송 함수 구현
  - `sendPushNotification(userId, notification, data)` - 단일 사용자
  - `sendPushNotificationToMultiple(userIds, notification, data)` - 다중 사용자
  - `sendPushNotificationToTopic(topic, notification, data)` - 토픽 기반
- ✅ Admin API에서 사업자 승인/거절 시 FCM 푸시 전송

### 3. Database
- ✅ `users` 테이블에 `fcm_token` 컬럼 추가 (SQL 스크립트 생성)

---

## 🚀 설정 및 실행

### Step 1: 패키지 설치

```bash
# Flutter 패키지 설치
flutter pub get

# Backend 패키지 확인 (이미 설치됨)
cd backend
npm install
```

### Step 2: Supabase에서 fcm_token 컬럼 추가

Supabase SQL Editor에서 다음 SQL 실행:

```bash
# 로컬에서 실행
psql -d your_database < database/add_fcm_token.sql
```

또는 Supabase Dashboard → SQL Editor에서 `/database/add_fcm_token.sql` 파일 내용 실행

### Step 3: Firebase 서비스 계정 키 설정

1. **Firebase Console** 이동:
   - https://console.firebase.google.com/
   - 프로젝트 선택: `allsuri`

2. **서비스 계정 키 생성**:
   - 좌측 메뉴: 프로젝트 설정 (⚙️) → 서비스 계정
   - "새 비공개 키 생성" 클릭
   - JSON 파일 다운로드 (예: `allsuri-firebase-adminsdk.json`)

3. **환경 변수 설정**:

```bash
# backend/.env 파일에 추가
FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"allsuri","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
```

**주의**: JSON 파일의 전체 내용을 **한 줄로** 압축하여 환경 변수로 설정해야 합니다.

```bash
# JSON을 한 줄로 압축하는 방법 (macOS/Linux)
cat allsuri-firebase-adminsdk.json | jq -c . | pbcopy
# 이제 복사된 내용을 .env 파일에 붙여넣기
```

### Step 4: 백엔드 재시작

```bash
cd backend
npm start
```

로그에서 다음 메시지 확인:
```
✅ Firebase Admin SDK 초기화 완료
```

### Step 5: 앱 빌드 및 실행

```bash
# Android
flutter run

# iOS (Mac only)
flutter run
```

---

## 📱 테스트 방법

### 1. 앱에서 로그인
```
앱 실행 → 카카오 로그인
```

로그 확인:
```
🔔 FCM 초기화 시작...
✅ FCM 권한 승인됨
🔑 FCM 토큰: cXyZ123...
💾 FCM 토큰 저장 중: kakao:4479276246
✅ FCM 토큰 저장 완료
```

### 2. Admin 페이지에서 사업자 승인
```
http://localhost:3001/admin.html (또는 https://api.allsuri.app/admin.html)
→ 사용자 관리 → 승인
```

백엔드 로그 확인:
```
[ADMIN] 승인 알림 전송 완료: kakao:4479276246
✅ FCM 푸시 알림 전송 성공: kakao:4479276246
```

### 3. 앱에서 알림 확인

**포그라운드 (앱이 열려 있을 때)**:
- 화면 상단에 로컬 알림 표시

**백그라운드/종료 상태**:
- 알림 트레이에 푸시 알림 표시
- 알림 탭 → 앱 열림

**알림 화면**:
- 하단 네비게이션 바 → 알림 아이콘
- 저장된 알림 목록 확인

---

## 🔧 다른 기능에서 FCM 사용하기

### 예제 1: 백엔드에서 푸시 전송 (Node.js)

```javascript
const { sendPushNotification } = require('./services/fcm_service');

// 단일 사용자에게 푸시 알림 전송
await sendPushNotification(
  userId,
  {
    title: '새 견적 요청',
    body: '강남구에서 에어컨 수리 견적 요청이 도착했습니다.',
  },
  {
    type: 'new_estimate',
    estimateId: '123',
    region: '강남구',
  }
);

// 여러 사용자에게 푸시 알림 전송
const { sendPushNotificationToMultiple } = require('./services/fcm_service');

await sendPushNotificationToMultiple(
  [userId1, userId2, userId3],
  {
    title: '이벤트 알림',
    body: '신규 회원 가입 이벤트가 시작되었습니다!',
  },
  {
    type: 'event',
  }
);

// 토픽에 푸시 알림 전송 (모든 사업자, 모든 고객 등)
const { sendPushNotificationToTopic } = require('./services/fcm_service');

await sendPushNotificationToTopic(
  'all_business',
  {
    title: '공지사항',
    body: '12월 25일 서버 점검이 예정되어 있습니다.',
  },
  {
    type: 'announcement',
  }
);
```

### 예제 2: Flutter에서 알림 받기

`FCMService`가 자동으로 처리하므로 추가 코드 불필요!

포그라운드/백그라운드 모두 자동으로 알림 표시됩니다.

---

## 📊 주요 함수 및 파일

### Flutter
| 파일 | 설명 |
|------|------|
| `lib/services/fcm_service.dart` | FCM 초기화, 토큰 관리, 알림 수신 처리 |
| `lib/services/auth_service.dart` | 로그인 시 FCM 토큰 저장, 로그아웃 시 삭제 |
| `lib/main.dart` | FCM 초기화 (앱 시작 시) |

### Backend
| 파일 | 설명 |
|------|------|
| `backend/src/services/fcm_service.js` | Firebase Admin SDK 초기화 및 푸시 전송 함수 |
| `backend/src/routes/admin.js` | 사업자 승인/거절 시 FCM 푸시 전송 |

### Database
| 파일 | 설명 |
|------|------|
| `database/add_fcm_token.sql` | `users` 테이블에 `fcm_token` 컬럼 추가 |
| `database/create_notifications_table.sql` | `notifications` 테이블 생성 |

---

## 🐛 트러블슈팅

### 1. FCM 토큰이 저장되지 않음
**증상**: 로그에 "FCM 토큰이 없습니다." 표시

**해결**:
- 앱 권한 확인: 설정 → 앱 → 올수리 → 알림 허용
- 앱 재시작
- 디바이스 로그 확인

### 2. 백엔드에서 푸시 전송 실패
**증상**: "Firebase Admin SDK 초기화 실패" 또는 "FIREBASE_SERVICE_ACCOUNT_KEY 환경 변수가 설정되지 않았습니다."

**해결**:
- `.env` 파일에 `FIREBASE_SERVICE_ACCOUNT_KEY` 설정 확인
- JSON 형식이 올바른지 확인 (한 줄로 압축되어 있어야 함)
- 백엔드 재시작: `npm start`

### 3. iOS에서 알림이 오지 않음
**증상**: Android는 되는데 iOS는 안 됨

**해결**:
- Firebase Console → 프로젝트 설정 → Cloud Messaging → APNs 인증 키 등록 필요
- Xcode에서 Signing & Capabilities → Push Notifications 활성화
- 실제 디바이스에서 테스트 (시뮬레이터는 푸시 알림 미지원)

### 4. 포그라운드에서 알림이 표시되지 않음
**증상**: 백그라운드는 되는데 포그라운드는 안 됨

**해결**:
- `flutter_local_notifications` 패키지가 제대로 설치되었는지 확인
- `FCMService`의 `_showLocalNotification` 함수 로그 확인

---

## 🎯 알림 타입 (Notification Types)

현재 구현된 알림 타입:

| 타입 | 설명 | 사용 예 |
|------|------|---------|
| `business_approved` | 사업자 승인 완료 | Admin에서 승인 시 |
| `business_rejected` | 사업자 승인 거절 | Admin에서 거절 시 |
| `new_estimate` | 새 견적 요청 | 고객이 견적 요청 시 |
| `estimate_update` | 견적 업데이트 | 사업자가 견적 수정 시 |
| `chat_message` | 채팅 메시지 | 새 메시지 도착 시 |
| `general` | 일반 알림 | 기타 알림 |

**새로운 타입 추가**:
백엔드에서 `type` 필드에 원하는 값을 지정하면 됩니다.

---

## 📚 참고 자료

- [Firebase Cloud Messaging 문서](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire 공식 문서](https://firebase.flutter.dev/docs/messaging/overview)
- [flutter_local_notifications 문서](https://pub.dev/packages/flutter_local_notifications)

---

## ✅ 체크리스트

설정이 완료되면 다음을 확인하세요:

- [ ] Supabase에 `fcm_token` 컬럼 추가됨
- [ ] Supabase에 `notifications` 테이블 생성됨
- [ ] Firebase 서비스 계정 키가 `.env`에 설정됨
- [ ] 백엔드 로그에 "Firebase Admin SDK 초기화 완료" 표시됨
- [ ] 앱 로그인 시 "FCM 토큰 저장 완료" 표시됨
- [ ] Admin에서 승인 시 백엔드 로그에 "FCM 푸시 알림 전송 성공" 표시됨
- [ ] 앱에서 푸시 알림 수신됨 (포그라운드/백그라운드 모두)
- [ ] 앱의 알림 화면에서 알림 목록 확인됨

모든 항목이 체크되면 FCM 푸시 알림 기능이 정상적으로 작동하는 것입니다! 🎉


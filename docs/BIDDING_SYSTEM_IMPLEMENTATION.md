# 오더 경쟁 입찰 시스템 구현 가이드

## 📋 개요

기존의 "즉시 가져가기" 시스템을 **경쟁 입찰 시스템**으로 변경:
1. 사업자가 "잡기" 클릭 → **입찰 생성**
2. 오더 소유자가 입찰자 목록 확인 → **사업자 선택**
3. 선택된 사업자에게 오더 이관
4. 선택되지 않은 사업자들에게 거절 알림

## 🗄️ 데이터베이스 스키마

### 1. `order_bids` 테이블
```sql
CREATE TABLE order_bids (
  id UUID PRIMARY KEY,
  listing_id UUID REFERENCES marketplace_listings(id),
  job_id UUID REFERENCES jobs(id),
  bidder_id UUID REFERENCES users(id),
  status TEXT ('pending', 'selected', 'rejected', 'withdrawn'),
  message TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### 2. `marketplace_listings` 테이블 확장
```sql
ALTER TABLE marketplace_listings
ADD COLUMN bid_count INTEGER DEFAULT 0,
ADD COLUMN selected_bidder_id UUID REFERENCES users(id);
```

## 🔧 구현 완료 사항

### ✅ 백엔드 API (Netlify Functions)

1. **`POST /api/market/listings/:id/bid`**
   - 입찰 생성
   - 오더 소유자에게 알림 전송
   - Response: `{success: true, bidId: "uuid"}`

2. **`GET /api/market/listings/:id/bids`**
   - 입찰 목록 조회 (오더 소유자만)
   - 사업자 프로필 정보 포함
   - Response: `[{id, bidder: {businessname, avatar_url, ...}, ...}]`

3. **`POST /api/market/listings/:id/select-bidder`**
   - 입찰자 선택 (오더 소유자만)
   - 선택된 사업자에게 알림
   - 거절된 사업자들에게 알림
   - 채팅방 자동 생성

4. **`POST /api/market/bids/:id/withdraw`**
   - 입찰 취소

### ✅ Flutter 클라이언트

1. **`marketplace_service.dart`**
   - `claimListing()` → `/bid` 엔드포인트 호출
   - 입찰 메시지 포함

2. **`order_marketplace_screen.dart`**
   - 입찰 성공 메시지: "승인을 기다리고 있어요~"
   - Realtime 이벤트 리스너 (UPDATE, DELETE)

## 📱 다음 구현 단계

### 1. 알림 시스템 (notifications 테이블)

**알림 타입:**
- `new_bid`: 새로운 입찰 ("사업자가 입찰했습니다")
- `bid_selected`: 입찰 선택됨 ("선택되었습니다!")
- `bid_rejected`: 입찰 거절됨 ("다른 사업자에게 이관되었습니다")

**구현 파일:**
- `lib/screens/notification/notification_screen.dart` (기존)
- Notification 클릭 → 입찰자 목록 화면으로 이동

### 2. 입찰자 목록 화면

**새 파일 생성:** `lib/screens/business/order_bidders_screen.dart`

**기능:**
- 입찰자 목록 표시
- 프로필 정보 (이름, 평점, 완료 건수)
- "선택하기" 버튼
- 선택 확인 다이얼로그

**API 호출:**
```dart
final response = await api.get('/market/listings/$listingId/bids');
```

### 3. 사업자 선택 흐름

```dart
Future<void> selectBidder(String listingId, String bidderId) async {
  final response = await api.post('/market/listings/$listingId/select-bidder', {
    'bidderId': bidderId,
    'ownerId': currentUserId,
  });
  
  if (response['success'] == true) {
    // 성공 메시지
    // 채팅으로 이동
  }
}
```

### 4. 기기 푸시 알림

**Firebase Cloud Messaging (FCM)**

1. **토큰 저장:**
```dart
// lib/services/notification_service.dart
Future<void> saveDeviceToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  await supabase.from('users').update({'fcm_token': token}).eq('id', userId);
}
```

2. **Supabase Function으로 FCM 전송:**
```typescript
// supabase/functions/send-push-notification.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { userId, title, body } = await req.json()
  
  // FCM token 조회
  const { data: user } = await supabase
    .from('users')
    .select('fcm_token')
    .eq('id', userId)
    .single()
  
  if (user?.fcm_token) {
    // FCM API 호출
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: user.fcm_token,
        notification: { title, body },
      }),
    })
  }
  
  return new Response('OK')
})
```

## 🧪 테스트 시나리오

### 시나리오 1: 입찰 생성
1. 사업자 B가 사업자 A의 오더에 "잡기" 클릭
2. ✅ "승인을 기다리고 있어요~" 메시지 표시
3. ✅ 사업자 A에게 알림: "새로운 입찰이 들어왔습니다"
4. ✅ 기기 푸시 알림 전송

### 시나리오 2: 입찰자 선택
1. 사업자 A가 알림 클릭
2. 입찰자 목록 화면 표시
3. 사업자 B 선택
4. ✅ 사업자 B에게 알림: "선택되었습니다!"
5. ✅ 다른 입찰자들에게 알림: "다른 사업자에게 이관되었습니다"
6. ✅ 채팅방 자동 생성

### 시나리오 3: Realtime 업데이트
1. 기기 A: 오더 목록 보기
2. 기기 B: 입찰
3. ✅ 기기 A: 자동으로 bid_count 업데이트
4. 기기 C: 입찰자 선택
5. ✅ 기기 A, B: 오더가 assigned 상태로 변경, 리스트에서 사라짐

## 📝 Supabase SQL 실행 순서

1. **`database/order_bids_system.sql`** - 입찰 테이블 및 RPC 함수
2. **`database/fix_claim_listing_for_created_status.sql`** - claim_listing RPC 수정

## 🔄 마이그레이션 가이드

### 기존 시스템에서 새 시스템으로

1. **데이터 정리:**
```sql
-- 기존 assigned 오더들을 그대로 유지
-- 새로운 오더부터 입찰 시스템 적용
```

2. **Flutter 업데이트:**
```bash
git pull origin main
flutter clean
flutter pub get
flutter run
```

3. **Netlify 재배포:**
- Git push 시 자동 배포
- 환경 변수 확인: `SUPABASE_JWT_SECRET`

## 🎯 성공 지표

- ✅ 입찰 생성 성공률 > 95%
- ✅ 알림 전송 성공률 > 90%
- ✅ Realtime 업데이트 지연 < 2초
- ✅ 기기 푸시 알림 수신률 > 85%

## 🐛 트러블슈팅

### 409 Conflict
- **원인:** 이미 입찰했거나 자기 자신의 오더
- **해결:** 중복 입찰 체크, 오더 소유자 확인

### 500 Internal Server Error
- **원인:** jobs 테이블 status constraint
- **해결:** `status = 'assigned'` 사용 (not 'in_progress')

### Realtime 이벤트 미수신
- **원인:** Supabase Realtime 비활성화
- **해결:** Supabase Dashboard에서 Realtime 활성화

## 📚 참고 자료

- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)


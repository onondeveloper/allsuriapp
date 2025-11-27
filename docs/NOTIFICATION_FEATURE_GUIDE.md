# 알림 기능 구현 가이드

## 📱 개요

allsuriapp의 알림 시스템은 **Supabase Realtime** 및 **FCM (Firebase Cloud Messaging)**을 활용하여 구현되었습니다.

---

## 🎯 알림 기능 목록

### 1. 알림 화면
- **경로**: `lib/screens/notification_history_screen.dart`
- **기능**:
  - 사용자가 받은 모든 알림을 시간순으로 표시
  - 읽음/안 읽음 상태 표시
  - 알림 클릭 시 해당 화면으로 이동
  - 모두 읽음 처리
  - Pull-to-refresh 지원

### 2. 알림 타입

| 타입 | 설명 | 이동 화면 |
|------|------|----------|
| **bid_received** | 새로운 입찰 접수 | 입찰자 목록 |
| **order_completed** | 공사 완료 확인 요청 | 리뷰 작성 |
| **review_received** | 리뷰 받음 | 프로필 |
| **order_status_changed** | 오더 상태 변경 | 오더 상세 |
| **chat_start** | 채팅 시작 | 채팅방 |
| **estimate_received** | 견적 접수 | 견적 상세 |

### 3. 알림 전송 시점

#### 3.1 입찰 알림
```dart
// 위치: lib/screens/business/order_marketplace_screen.dart
// 사업자가 오더에 입찰할 때
await notificationService.sendNotification(
  toUserId: listingOwnerId,
  title: '새로운 입찰이 접수되었습니다',
  body: '$businessName님이 입찰했습니다',
  type: 'bid_received',
  listingId: listingId,
);
```

#### 3.2 공사 완료 알림
```dart
// 위치: lib/screens/business/job_management_screen.dart
// 낙찰받은 사업자가 '공사 완료' 버튼 클릭 시
await Supabase.instance.client
    .from('notifications')
    .insert({
      'userid': listingOwnerId,
      'title': '공사 완료 확인 요청',
      'body': '${job.title} 공사가 완료되었습니다',
      'type': 'order_completed',
      'jobid': job.id,
});
```

#### 3.3 리뷰 알림
```dart
// 위치: lib/screens/business/order_review_screen.dart
// 오더 소유자가 리뷰 작성 완료 시
await notificationService.sendNotification(
  toUserId: revieweeId,
  title: '리뷰가 작성되었습니다',
  body: '새로운 리뷰를 확인해보세요!',
  type: 'review_received',
);
```

#### 3.4 채팅 알림
```dart
// 위치: lib/services/chat_service.dart
// 메시지 전송 시
await _notificationService.sendChatNotification(
  toUserId: recipientId,
  fromUserId: senderId,
  message: messageContent,
  chatroomId: chatRoomId,
);
```

---

## 🏗️ 아키텍처

### 1. Realtime 구독
```dart
// lib/screens/business/my_order_management_screen.dart
_channel = Supabase.instance.client
    .channel('marketplace_listings_channel')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'marketplace_listings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'posted_by',
        value: currentUserId,
      ),
      callback: (payload) {
        // 상태 변경 감지 → 알림 표시
        if (newStatus == 'awaiting_confirmation') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('공사가 완료되었습니다!')),
          );
        }
      },
    )
    .subscribe();
```

### 2. FCM 푸시 알림
```dart
// lib/services/notification_service.dart
Future<void> sendNotification({
  required String toUserId,
  required String title,
  required String body,
  required String type,
}) async {
  await _sb.from('notifications').insert({
    'userid': toUserId,
    'title': title,
    'body': body,
    'type': type,
    'isread': false,
    'createdat': DateTime.now().toIso8601String(),
  });
}
```

---

## 📊 데이터베이스 스키마

### notifications 테이블
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userid UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT,
  type TEXT NOT NULL,
  job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
  listing_id UUID REFERENCES marketplace_listings(id) ON DELETE SET NULL,
  isread BOOLEAN DEFAULT false,
  createdat TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_notifications_userid ON notifications(userid);
CREATE INDEX idx_notifications_createdat ON notifications(createdat DESC);
CREATE INDEX idx_notifications_isread ON notifications(isread);
```

---

## 🎨 UI 컴포넌트

### 알림 카드
```dart
Container(
  decoration: BoxDecoration(
    color: isUnread 
        ? AppConstants.primaryColor.withOpacity(0.05) 
        : Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isUnread 
          ? AppConstants.primaryColor.withOpacity(0.3) 
          : Colors.grey[200]!,
    ),
  ),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: _getIconColor(type).withOpacity(0.1),
      child: Icon(_getIcon(type), color: _getIconColor(type)),
    ),
    title: Text(title, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
    subtitle: Text(body),
    trailing: isUnread ? Badge() : null,
  ),
)
```

### 읽지 않은 알림 배지
```dart
// 위치: AppBar actions
if (unreadCount > 0)
  Badge(
    label: Text('$unreadCount'),
    child: IconButton(
      icon: Icon(Icons.notifications),
      onPressed: () => Navigator.push(...),
    ),
  )
```

---

## ⚙️ 설정

### 1. 알림 권한 요청
```dart
// lib/services/local_notification_service.dart
await FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

### 2. FCM 토큰 관리
```dart
final fcmToken = await FirebaseMessaging.instance.getToken();
// users 테이블에 저장
await Supabase.instance.client
    .from('users')
    .update({'fcm_token': fcmToken})
    .eq('id', userId);
```

---

## 🔔 알림 흐름도

```
1. 이벤트 발생 (입찰, 공사 완료, 리뷰 등)
   ↓
2. NotificationService.sendNotification() 호출
   ↓
3. notifications 테이블에 INSERT
   ↓
4. FCM을 통해 푸시 알림 전송 (백그라운드)
   ↓
5. 사용자 앱에서 알림 수신
   ↓
6. 알림 클릭 → 해당 화면으로 이동
   ↓
7. isread = true로 업데이트
```

---

## 🐛 문제 해결

### 알림이 전송되지 않을 때

1. **notifications 테이블 확인**:
```sql
SELECT * FROM notifications 
WHERE userid = 'user-id' 
ORDER BY createdat DESC 
LIMIT 10;
```

2. **RLS 정책 확인**:
```sql
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'notifications';
```

3. **외래 키 제약 조건 확인**:
```sql
-- job_id, listing_id가 nullable인지 확인
SELECT column_name, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND column_name IN ('job_id', 'listing_id');
```

### 알림이 실시간으로 표시되지 않을 때

1. **Realtime 구독 상태 확인**:
```dart
print('구독 상태: ${_channel.subscribe().status}');
```

2. **Supabase Realtime 활성화 확인**:
```sql
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';
```

---

## 📱 사용자 경험

### 1. 인앱 알림
- 스낵바 또는 배너로 즉시 표시
- 3-5초 후 자동 사라짐
- 탭하면 해당 화면으로 이동

### 2. 푸시 알림
- 앱이 백그라운드일 때 표시
- 알림 센터에 누적
- 탭하면 앱 실행 + 해당 화면으로 이동

### 3. 알림 히스토리
- 모든 알림 기록 보관
- 날짜별로 그룹화
- 무한 스크롤 지원

---

## ✅ 구현 완료 기능

- [x] 입찰 접수 알림
- [x] 공사 완료 알림
- [x] 리뷰 작성 알림
- [x] 채팅 메시지 알림
- [x] 알림 히스토리 화면
- [x] 읽음/안 읽음 상태
- [x] 모두 읽음 처리
- [x] Pull-to-refresh
- [x] 알림 클릭 시 해당 화면 이동
- [x] Realtime 실시간 알림

---

## 🚀 향후 개선 사항

- [ ] 알림 설정 (알림 타입별 on/off)
- [ ] 알림 삭제 기능
- [ ] 알림 필터링 (읽음/안 읽음)
- [ ] 알림 음소거 (방해 금지 모드)
- [ ] 알림 그룹화 (같은 타입 묶기)

---

**마지막 업데이트**: 2025-11-27
**버전**: 1.0.0


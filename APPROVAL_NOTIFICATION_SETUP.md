# 사업자 승인 알림 설정 가이드

## 🎯 개요
관리자가 사업자를 승인하면 앱에서 자동으로 알림을 받을 수 있는 기능이 추가되었습니다.

## 📋 작업 완료 사항

### 1. ✅ 백엔드 API 수정 완료
- `backend/src/routes/admin.js` - 승인/거절 시 자동 알림 전송
- `businessStatus` → `businessstatus` 컬럼명 수정 (DB와 일치)

### 2. ✅ SQL 스크립트 생성
- `database/approve_user.sql` - 사용자 승인 및 상태 확인
- `database/create_notifications_table.sql` - 알림 테이블 생성

## 🚀 설정 방법

### Step 1: Notifications 테이블 생성 (Supabase SQL Editor)

```sql
-- database/create_notifications_table.sql 파일 내용을 실행하세요
```

이 스크립트는:
- notifications 테이블 생성 (없는 경우)
- 필요한 인덱스 생성
- RLS (Row Level Security) 정책 설정

### Step 2: 현재 사용자 승인 (즉시 해결)

Supabase SQL Editor에서 실행:
```sql
-- "개발자" 사용자 강제 승인
UPDATE users
SET businessstatus = 'approved'
WHERE kakao_id = '4479276246';
```

### Step 3: 백엔드 서버 재시작

```bash
cd backend
npm restart
# 또는
pm2 restart all
```

### Step 4: 앱 테스트

1. **앱 완전 종료**
2. **앱 재실행**
3. **카카오 로그인**
4. 로그 확인:
   ```
   🔍 [HomeScreen] 사업자 사용자 정보:
      - Business Status (원본): approved
      ✅ 승인됨 -> BusinessDashboard로 이동
   ```

## 🔔 알림 작동 방식

### 승인 시
```javascript
{
  title: "🎉 사업자 승인 완료",
  body: "호인님의 사업자 계정이 승인되었습니다. 이제 견적 요청을 받을 수 있습니다!",
  type: "business_approved"
}
```

### 거절 시
```javascript
{
  title: "사업자 승인 거절",
  body: "사업자 계정 승인이 거절되었습니다. 자세한 사항은 고객센터로 문의해주세요.",
  type: "business_rejected"
}
```

## 📱 앱에서 알림 확인 방법

현재 `NotificationService`가 구현되어 있어서 다음과 같이 알림을 가져올 수 있습니다:

```dart
final notificationService = NotificationService();

// 알림 목록 가져오기
final notifications = await notificationService.getNotifications(userId);

// 읽지 않은 알림 개수
final unreadCount = await notificationService.getUnreadCount(userId);

// 알림 읽음 처리
await notificationService.markAsRead(notificationId);
```

## 🎨 다음 단계: UI 개선 (선택사항)

### 1. 알림 아이콘 추가
BusinessDashboard 상단에 알림 벨 아이콘 추가:
```dart
AppBar(
  actions: [
    IconButton(
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        child: Icon(Icons.notifications),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationListScreen(),
          ),
        );
      },
    ),
  ],
)
```

### 2. 실시간 알림 구독
Supabase Realtime을 사용하여 실시간 알림:
```dart
final subscription = supabase
  .from('notifications')
  .stream(primaryKey: ['id'])
  .eq('userid', userId)
  .listen((data) {
    // 새 알림 표시
    showNotificationSnackbar(data);
  });
```

## 🔍 트러블슈팅

### 문제: 여전히 pending으로 표시됨

**해결책 1**: Supabase에서 직접 확인
```sql
SELECT id, name, businessstatus, businessname
FROM users
WHERE kakao_id = '4479276246';
```

**해결책 2**: 강제 업데이트
```sql
UPDATE users
SET businessstatus = 'approved'
WHERE kakao_id = '4479276246';
```

**해결책 3**: 앱 캐시 삭제
- 앱 완전 종료
- 앱 데이터 삭제 (설정 > 앱 > 올수리 > 저장소 > 데이터 삭제)
- 재설치

### 문제: 알림이 안 옴

**확인 사항**:
1. notifications 테이블이 생성되었는지 확인
2. 백엔드 서버 로그 확인:
   ```
   [ADMIN] 승인 알림 전송 완료: {userId}
   ```
3. Supabase에서 알림 확인:
   ```sql
   SELECT * FROM notifications
   WHERE userid = '{userId}'
   ORDER BY createdat DESC;
   ```

## 📊 Admin Page 사용법

### 사용자 승인
1. Admin 페이지 접속 (http://localhost:3001/admin.html)
2. 사용자 관리 클릭
3. 이름 클릭하여 상세 보기
4. "승인" 버튼 클릭
5. ✅ 자동으로 알림 전송됨!

### 상태 확인
- 검색창에서 상호/이름/전화번호 검색 가능
- 상태 컬럼: 
  - 🟡 승인됨 (approved)
  - 🔵 대기중 (pending)
  - 🔴 거절됨 (rejected)

## 💡 추가 기능 아이디어

1. **푸시 알림** (FCM)
   - Firebase Cloud Messaging 설정
   - 앱이 종료되어 있어도 알림 수신

2. **이메일 알림**
   - 승인 시 이메일 자동 발송
   - SendGrid, Mailgun 등 사용

3. **SMS 알림**
   - 중요한 알림은 SMS로도 전송
   - Twilio, 알리고 등 사용

4. **알림 센터**
   - 전용 알림 목록 화면
   - 필터링 및 검색 기능
   - 알림 삭제 기능

## 📝 참고사항

- 알림은 Supabase notifications 테이블에 저장됩니다
- RLS 정책으로 사용자는 자신의 알림만 볼 수 있습니다
- 알림은 30일 후 자동 삭제되도록 cron job 설정 권장
- 알림 전송 실패해도 승인 프로세스는 정상 진행됩니다


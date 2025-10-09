# 카카오톡 공유 기능 설정 가이드

## 1. 오픈채팅방 URL 설정

`lib/services/kakao_share_service.dart` 파일에서 오픈채팅방 URL을 설정하세요:

```dart
// 올수리 오픈채팅방 URL (실제 오픈채팅방 URL로 교체 필요)
static const String openChatUrl = 'https://open.kakao.com/o/gv9woeWh';
```

### 오픈채팅방 URL 얻는 방법:
1. 카카오톡 앱에서 오픈채팅방 생성
2. 채팅방 설정 → 공유하기 → 링크 복사
3. 복사한 링크를 `openChatUrl`에 붙여넣기

예시: `https://open.kakao.com/o/s1234567`

## 2. 카카오 개발자 콘솔 설정

### 2.1 플랫폼 등록 (Android)
1. [Kakao Developers](https://developers.kakao.com/) 로그인
2. 내 애플리케이션 → 앱 선택
3. 플랫폼 → Android 플랫폼 등록
   - 패키지명: `com.ononcompany.allsuriapp`
   - 마켓 URL: (선택사항)
   - 키 해시: 디버그/릴리스 키 해시 등록

### 2.2 카카오 로그인 활성화
1. 제품 설정 → 카카오 로그인
2. 활성화 설정: ON
3. Redirect URI: (이미 설정됨)

### 2.3 카카오톡 공유 활성화
1. 제품 설정 → 카카오톡 공유
2. 활성화 설정: ON
3. 도메인 등록: `allsuri.app` (웹 공유용)

## 3. 기능 동작 방식

### 견적 요청 제출 후:
1. 견적 요청이 성공적으로 제출되면 자동으로 공유 다이얼로그가 표시됩니다
2. 사용자가 "공유하기" 버튼을 클릭하면:
   - 카카오톡이 설치된 경우: 카카오톡 공유 시트가 열립니다
   - 카카오톡 미설치: 웹 브라우저로 공유 페이지가 열립니다
3. 공유 메시지에는 다음이 포함됩니다:
   - 견적 요청 제목, 카테고리, 주소
   - 오픈채팅방 참여 버튼
   - 앱에서 보기 버튼

### 공유 대상:
- **나에게 보내기**: 사용자가 자신에게 메시지를 보내 기록 보관
- **친구에게 보내기**: 다른 사람과 견적 정보 공유
- **오픈채팅방**: 오픈채팅방에 직접 공유 가능

## 4. 테스트 방법

### 4.1 에뮬레이터에서 테스트
에뮬레이터에는 카카오톡이 설치되어 있지 않으므로 웹 공유 URL이 브라우저로 열립니다.

### 4.2 실제 기기에서 테스트
1. 카카오톡이 설치된 Android 기기에 앱 설치
2. 견적 요청 제출
3. 공유 다이얼로그에서 "공유하기" 클릭
4. 카카오톡 공유 시트 확인
5. "나에게 보내기" 선택하여 테스트

## 5. 커스터마이징

### 공유 메시지 템플릿 수정:
`lib/services/kakao_share_service.dart`의 `shareEstimate` 메서드에서 `FeedTemplate`을 수정하세요:

```dart
final template = FeedTemplate(
  content: Content(
    title: '🔧 $title',  // 제목 커스터마이징
    description: '...',   // 설명 커스터마이징
    imageUrl: Uri.parse('...'),  // 이미지 URL 변경
    link: Link(...),
  ),
  buttons: [
    Button(
      title: '오픈채팅방 참여하기',  // 버튼 텍스트 변경
      link: Link(...),
    ),
  ],
);
```

### 공유 다이얼로그 UI 수정:
`lib/screens/customer/create_request_screen.dart`의 `_showKakaoShareDialog` 메서드를 수정하세요.

## 6. 주의사항

- 카카오톡 공유는 카카오 개발자 콘솔에서 앱 검수 없이 바로 사용 가능합니다
- 메시지 API (자동 전송)는 검수가 필요하므로 공유 시트 방식을 권장합니다
- 오픈채팅방 URL은 반드시 실제 오픈채팅방 링크로 교체해야 합니다
- 공유 이미지는 HTTPS URL이어야 하며, 최소 200x200 크기를 권장합니다

## 7. 문제 해결

### 공유가 안 될 때:
1. 카카오 개발자 콘솔에서 "카카오톡 공유" 활성화 확인
2. AndroidManifest.xml의 queries 설정 확인
3. 패키지명과 키 해시가 정확한지 확인
4. 로그에서 에러 메시지 확인

### 오픈채팅방 링크가 안 열릴 때:
1. 오픈채팅방이 공개 설정인지 확인
2. URL이 정확한지 확인 (https://open.kakao.com/o/...)
3. 카카오톡 앱이 최신 버전인지 확인


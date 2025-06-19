# AllSuri App Storyboard

## 1. 앱 개요
AllSuri는 사용자들이 다양한 서비스를 주문하고 제공할 수 있는 플랫폼입니다. 주요 기능으로는 서비스 주문, 이미지 업로드, 실시간 채팅, 주문 관리 등이 있습니다.

## 2. 사용자 역할 (User Roles)

### 2.1 일반 사용자 (Customer)
- 서비스 주문 및 결제
- 주문 내역 조회
- 실시간 채팅
- 프로필 관리
- 이미지 업로드

### 2.2 서비스 제공자 (Service Provider)
- 주문 수락/거절
- 서비스 제공
- 실시간 채팅
- 프로필 관리
- 수익 관리

## 3. 주요 기능 및 사용자 흐름

### 3.1 회원가입 및 로그인
1. 회원가입
   - 이메일/비밀번호 입력
   - 사용자 역할 선택 (일반 사용자/서비스 제공자)
   - 프로필 정보 입력
   - AWS Cognito 인증

2. 로그인
   - 이메일/비밀번호 입력
   - 자동 로그인 지원
   - 비밀번호 재설정 기능

### 3.2 서비스 주문 프로세스
1. 주문 생성
   - 서비스 카테고리 선택
   - 상세 설명 입력
   - 이미지 업로드 (선택사항)
     * 이미지 선택
     * 이미지 크롭
     * 이미지 압축
     * S3 업로드
   - 위치 정보 입력
   - 예상 비용 입력
   - 주문 생성

2. 주문 관리
   - 주문 상태 확인
   - 실시간 채팅
   - 주문 취소
   - 결제 처리

### 3.3 채팅 시스템
1. 채팅방 목록
   - 활성 채팅방 표시
   - 최근 메시지 미리보기
   - 읽지 않은 메시지 표시

2. 채팅 기능
   - 실시간 메시지 전송
   - 이미지 공유
   - 위치 공유
   - 채팅방 나가기

### 3.4 주문 관리
1. 주문 목록
   - 진행 중인 주문
   - 완료된 주문
   - 취소된 주문

2. 주문 상세
   - 주문 상태
   - 서비스 제공자 정보
   - 채팅 바로가기
   - 결제 정보

### 3.5 프로필 관리
1. 프로필 정보
   - 기본 정보 수정
   - 프로필 이미지 변경
   - 연락처 정보 관리

2. 설정
   - 알림 설정
   - 개인정보 설정
   - 계정 관리

## 4. 데이터 흐름

### 4.1 데이터 저장소
- AWS DynamoDB
  * 사용자 정보
  * 주문 정보
  * 채팅 메시지
  * 프로필 정보

- AWS S3
  * 프로필 이미지
  * 주문 관련 이미지
  * 채팅 이미지

### 4.2 실시간 데이터 동기화
- WebSocket 연결
  * 채팅 메시지
  * 주문 상태 업데이트
  * 알림

## 5. 보안 및 인증

### 5.1 인증 시스템
- AWS Cognito
  * 사용자 인증
  * 토큰 관리
  * 세션 관리

### 5.2 데이터 보안
- 이미지 업로드 보안
  * S3 버킷 정책
  * 접근 제어
  * 암호화

- API 보안
  * API Gateway
  * IAM 역할
  * 요청 검증

## 6. 사용자 인터페이스

### 6.1 주요 화면
1. 홈 화면
   - 서비스 카테고리
   - 추천 서비스
   - 최근 주문

2. 주문 화면
   - 주문 생성 폼
   - 이미지 업로드
   - 위치 선택

3. 채팅 화면
   - 채팅방 목록
   - 메시지 입력
   - 미디어 공유

4. 프로필 화면
   - 사용자 정보
   - 설정 메뉴
   - 주문 내역

### 6.2 UI/UX 특징
- 직관적인 네비게이션
- 실시간 피드백
- 부드러운 애니메이션
- 다크 모드 지원
- 반응형 디자인

## 7. 기술 스택

### 7.1 프론트엔드
- Flutter
- Dart
- Provider (상태 관리)
- WebSocket (실시간 통신)

### 7.2 백엔드
- AWS Cognito (인증)
- AWS DynamoDB (데이터베이스)
- AWS S3 (이미지 저장)
- AWS API Gateway (API)

### 7.3 개발 도구
- Android Studio / VS Code
- Git (버전 관리)
- CocoaPods (iOS 의존성)
- Gradle (Android 빌드)

## 8. 향후 개선 사항
1. 결제 시스템 통합
2. 푸시 알림 구현
3. 다국어 지원
4. 성능 최적화
5. 테스트 자동화
6. 사용자 피드백 시스템

## 9. 구현 계획

### 9.1 UI: 견적 추가 버튼 및 폼

- `lib/screens/order/create_order_screen.dart`에 견적 추가 폼이 이미 있다면, 이 화면을 각 역할별로 접근할 수 있도록 라우팅/버튼을 추가
- 없다면 새로 생성

### 9.2 OrderService/DynamoDBService: 실제 저장 구현

- `OrderService`에 `createOrder` 메서드가 이미 있다면, 이 메서드가 DynamoDB에 저장하도록 연결
- `DynamoDBService`의 `createOrder` 메서드가 실제 AWS에 저장하도록 구현(현재는 목업이므로 실제 연동 필요)

### 9.3 DynamoDB 연동 코드 예시

`lib/services/dynamodb_service.dart`에 아래와 같이 실제 AWS에 저장하는 코드 추가(실제 AWS 자격증명 필요):

```dart
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import '../config/aws_config.dart';

class DynamoDBService {
  final DynamoDB _dynamoDB;

  DynamoDBService(this._dynamoDB);

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    await _dynamoDB.putItem(
      tableName: AwsConfig.ordersTable,
      item: orderData.map((k, v) => MapEntry(k, AttributeValue(s: v.toString()))),
    );
  }
}
```

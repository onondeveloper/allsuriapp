# UI Improvement Guide
E-commerce 템플릿 스타일 적용 가이드

## 📦 새로 추가된 컴포넌트

### 1. AppConstants (`lib/config/app_constants.dart`)
E-commerce 템플릿의 디자인 시스템을 적용한 상수 파일

**주요 색상:**
- `primaryColor`: `Color(0xFF7B61FF)` - 보라색 (메인 색상)
- `secondaryColor`: `Color(0xFF2ED573)` - 초록색 (성공/진행 중)
- `errorColor`: `Color(0xFFEA5B5B)` - 빨간색 (에러/취소)
- `warningColor`: `Color(0xFFFFBE21)` - 노란색 (경고/대기)

**간격 (Spacing):**
- `defaultPadding`: 16.0
- `smallPadding`: 8.0
- `largePadding`: 24.0

**둥근 모서리 (Border Radius):**
- `defaultBorderRadius`: 12.0
- `smallBorderRadius`: 8.0
- `largeBorderRadius`: 20.0

### 2. ModernOrderCard (`lib/widgets/modern_order_card.dart`)
E-commerce 템플릿의 ProductCard 스타일을 적용한 오더 카드

**특징:**
- OutlinedButton 기반 (깔끔한 테두리)
- 상태별 색상 코드 배지
- 정보 칩 (카테고리, 지역, 입찰 수)
- 커스텀 배지 지원
- 액션 버튼 슬롯

**사용 예시:**
```dart
ModernOrderCard(
  title: "화장실 수리",
  description: "화장실 배관이 막혔습니다...",
  category: "수도",
  region: "서울 강남구",
  budget: 150000,
  status: "open",
  bidCount: 3,
  onTap: () {
    // 상세 화면으로 이동
  },
  actionButton: ModernButton(
    text: "오더 잡기",
    icon: Icons.touch_app_rounded,
    onPressed: () {
      // 오더 잡기 액션
    },
  ),
  badges: [
    // 커스텀 배지 (예: "내 입찰", "낙찰 대기" 등)
  ],
)
```

### 3. ModernButton (`lib/widgets/modern_button.dart`)
E-commerce 템플릿의 버튼 스타일 적용

**종류:**
1. **ModernButton** - 기본 버튼 (filled 또는 outlined)
2. **ModernSmallButton** - 작은 버튼 (칩 스타일)

**사용 예시:**
```dart
// Filled Button
ModernButton(
  text: "공사 완료",
  icon: Icons.check_circle,
  backgroundColor: AppConstants.secondaryColor,
  onPressed: () {},
)

// Outlined Button
ModernButton(
  text: "취소",
  isOutlined: true,
  onPressed: () {},
)

// Loading State
ModernButton(
  text: "처리 중...",
  isLoading: true,
  onPressed: null,
)

// Small Button
ModernSmallButton(
  text: "입찰",
  icon: Icons.gavel,
  onPressed: () {},
)
```

## 🎨 적용 방법

### 1. Order Marketplace Screen
**파일:** `lib/screens/business/order_marketplace_screen.dart`

**변경 사항:**
1. Import 추가:
```dart
import 'package:allsuriapp/widgets/modern_order_card.dart';
import 'package:allsuriapp/widgets/modern_button.dart';
import 'package:allsuriapp/config/app_constants.dart';
```

2. 기존 카드를 ModernOrderCard로 교체:
```dart
// Before: InteractiveCard 또는 Container 기반 카드
// After:
ModernOrderCard(
  title: listing['title'],
  description: listing['description'],
  category: listing['category'],
  region: listing['region'],
  budget: listing['budget_amount']?.toDouble(),
  status: listing['status'],
  bidCount: listing['bid_count'],
  onTap: () => _showOrderDetail(listing),
  actionButton: _buildActionButton(listing),
  badges: _buildBadges(listing),
)
```

3. 버튼을 ModernButton으로 교체:
```dart
// Before: ElevatedButton
ElevatedButton.icon(
  onPressed: () {},
  icon: Icon(Icons.touch_app),
  label: Text('오더 잡기'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    // ...
  ),
)

// After: ModernButton
ModernButton(
  text: "오더 잡기",
  icon: Icons.touch_app_rounded,
  backgroundColor: AppConstants.warningColor,
  onPressed: () {},
)
```

### 2. Job Management Screen
**파일:** `lib/screens/business/job_management_screen.dart`

**변경 사항:**
1. Import 추가 (동일)
2. _ModernJobsList 위젯의 카드를 ModernOrderCard로 교체
3. 버튼들을 ModernButton으로 교체

### 3. My Order Management Screen
**파일:** `lib/screens/business/my_order_management_screen.dart`

**변경 사항:**
1. Import 추가 (동일)
2. 오더 카드를 ModernOrderCard로 교체
3. 액션 버튼들을 ModernButton으로 교체

## 🎯 색상 가이드

### 상태별 색상
- **생성됨/입찰 중**: `AppConstants.primaryColor` (보라색)
- **진행 중/완료**: `AppConstants.secondaryColor` (초록색)
- **대기 중**: `AppConstants.warningColor` (노란색)
- **취소/에러**: `AppConstants.errorColor` (빨간색)

### 텍스트 색상
- **제목**: `AppConstants.blackColor` (진한 검정)
- **본문**: `AppConstants.blackColor60` (회색)
- **보조**: `AppConstants.blackColor40` (연한 회색)

### 배경 색상
- **카드**: `Colors.white`
- **화면**: `AppConstants.lightGreyColor` 또는 `Colors.grey[50]`

## 📐 간격 가이드

### 카드 내부
- 섹션 간: `AppConstants.defaultPadding` (16.0)
- 요소 간: `AppConstants.smallPadding` (8.0)
- 큰 섹션 간: `AppConstants.largePadding` (24.0)

### 리스트
- 카드 간격: 12.0
- 좌우 패딩: 16.0

## 🔄 마이그레이션 체크리스트

### Phase 1: 핵심 화면 (우선순위 높음)
- [ ] Order Marketplace Screen
- [ ] Job Management Screen
- [ ] My Order Management Screen

### Phase 2: 상세 화면
- [ ] Order Detail Dialog/Screen
- [ ] Job Detail Dialog/Screen
- [ ] Order Bidders Screen

### Phase 3: 기타 화면
- [ ] Estimate Management Screen
- [ ] Profile Screen
- [ ] Notification Screen

## 💡 Best Practices

1. **일관성 유지**
   - 모든 카드는 ModernOrderCard 사용
   - 모든 버튼은 ModernButton 사용
   - 색상은 AppConstants에서 가져오기

2. **간격 표준화**
   - 하드코딩된 숫자 대신 AppConstants 사용
   - `const EdgeInsets.all(16)` → `const EdgeInsets.all(AppConstants.defaultPadding)`

3. **색상 표준화**
   - `Color(0xFF...)` 대신 AppConstants 사용
   - 상태별 색상은 `_getStatusColor()` 메서드 활용

4. **애니메이션**
   - Duration은 AppConstants 사용
   - `Duration(milliseconds: 300)` → `AppConstants.defaultDuration`

## 🚀 다음 단계

1. ✅ AppConstants 생성
2. ✅ ModernOrderCard 생성
3. ✅ ModernButton 생성
4. ⏳ Order Marketplace Screen 적용
5. ⏳ Job Management Screen 적용
6. ⏳ My Order Management Screen 적용
7. ⏳ 테스트 및 피드백

## 📸 Before & After 비교

### Before (현재)
- 다양한 스타일의 카드 (Container, Card, InteractiveCard)
- 불일치하는 색상과 간격
- 다양한 버튼 스타일

### After (개선)
- 통일된 ModernOrderCard
- 일관된 색상 팔레트 (E-commerce 템플릿 기반)
- 표준화된 ModernButton
- 깔끔한 아웃라인 스타일
- 상태별 색상 코드


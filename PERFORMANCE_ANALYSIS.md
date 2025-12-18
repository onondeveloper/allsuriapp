# 올수리 앱 성능 분석 및 개선 방안

## 📊 현재 성능 문제점

### 1️⃣ **ProfessionalDashboard 로딩 지연**

#### 문제점:
```dart
// 5개의 개별 쿼리를 병렬 실행
Future.wait([
  _getCompletedJobsCount(currentUserId),    // DB 쿼리 1
  _getInProgressJobsCount(currentUserId),   // DB 쿼리 2
  _getNewOrdersCount(currentUserId),        // 전체 오더 count
  _getMyBidsCount(currentUserId),           // API + DB 이중 쿼리
  _getMyOrdersCount(currentUserId),         // DB 쿼리 3
])
```

**특히 문제가 되는 부분:**
- `_getMyBidsCount`: API 호출 후 다시 Supabase에서 listings 조회 (이중 쿼리)
- `_getNewOrdersCount`: 모든 오더를 카운트 (매우 느림)
- 각 쿼리가 독립적으로 실행되어 총 5-7개의 네트워크 요청 발생

#### 개선 방안:
✅ **백엔드 집계 API 생성**: 한 번의 API 호출로 모든 통계 반환
✅ **캐싱**: 30초-1분 캐시로 반복 로딩 시 성능 향상
✅ **점진적 로딩**: 중요 데이터 먼저 표시, 나머지는 점진적 로드

---

### 2️⃣ **OrderMarketplaceScreen 초기 로딩 지연**

#### 문제점:
```dart
Future<List<Map<String, dynamic>>> _loadInitialData() async {
  // 1. API 호출 - 내 입찰 목록
  final response = await _api.get('/market/bids?...');
  
  // 2. Supabase 쿼리 - 전체 오더 목록
  final allListings = await _market.listListings(...);
  
  // 3. 클라이언트 필터링 (비효율)
  final visibleItems = items.where((row) {
    // 상태 체크, 자신 제외 등
  }).toList();
}
```

**문제:**
- 순차적 실행 (API → Supabase)
- 모든 데이터를 가져온 후 클라이언트에서 필터링
- 페이지네이션 없음

#### 개선 방안:
✅ **병렬 실행**: `Future.wait`로 API와 Supabase 동시 호출
✅ **서버 사이드 필터링**: WHERE 절로 필요한 데이터만 가져오기
✅ **페이지네이션**: 초기 20개만 로드, 스크롤 시 추가 로드
✅ **인덱스 추가**: `status`, `posted_by`, `created_at` 컬럼 인덱싱

---

### 3️⃣ **이미지 로딩 최적화 부재**

#### 문제점:
- 광고 배너, 프로필 이미지 등이 매번 다시 로드됨
- 썸네일 없이 원본 이미지 로드
- 네트워크 대역폭 낭비

#### 개선 방안:
✅ **이미지 캐싱**: `CachedNetworkImage` 적극 활용
✅ **썸네일 생성**: Supabase Storage의 transformation API 사용
✅ **Lazy Loading**: 스크롤 시에만 이미지 로드

---

### 4️⃣ **과도한 Realtime 구독**

#### 문제점:
```dart
// 각 화면마다 realtime 구독
_channel = Supabase.instance.client
    .channel('marketplace_listings')
    .onPostgresChanges(...)
```

- 화면마다 개별 채널 생성
- 불필요한 데이터 수신
- 메모리 누수 가능성

#### 개선 방안:
✅ **전역 Realtime 관리**: 하나의 서비스로 통합 관리
✅ **필터링 강화**: 필요한 이벤트만 구독
✅ **Dispose 확실히**: 화면 종료 시 구독 해제

---

### 5️⃣ **비효율적인 Count 쿼리**

#### 문제점:
```dart
// 매번 전체 레코드를 count
await Supabase.instance.client
    .from('jobs')
    .select('*')  // 불필요한 데이터 조회
    .eq('assigned_business_id', userId)
    .count(CountOption.exact);
```

#### 개선 방안:
✅ **Count 전용 쿼리**: `select('id')` 또는 `select('count')`만 사용
✅ **Materialized View**: 자주 조회되는 통계는 뷰로 생성
✅ **캐싱 레이어**: Redis 등으로 count 캐싱

---

## 🚀 우선순위별 개선 작업

### 🔴 **High Priority (즉시 개선 가능)**

1. **OrderMarketplaceScreen 병렬 로딩**
   - API와 Supabase 쿼리를 `Future.wait`로 병렬화
   - 예상 개선: 50% 속도 향상

2. **Dashboard Count 쿼리 최적화**
   - `_getMyBidsCount`의 이중 쿼리 제거
   - `_getNewOrdersCount` 서버사이드 필터링
   - 예상 개선: 30-40% 속도 향상

3. **이미지 캐싱 활성화**
   - `CachedNetworkImage` 적용 확대
   - 예상 개선: 반복 로딩 시 80% 속도 향상

### 🟡 **Medium Priority (1-2일 소요)**

4. **페이지네이션 구현**
   - 초기 20개 항목만 로드
   - 무한 스크롤 적용

5. **백엔드 집계 API 추가**
   - `/dashboard/stats` 엔드포인트 생성
   - 한 번의 호출로 모든 통계 반환

6. **데이터베이스 인덱스 추가**
   ```sql
   CREATE INDEX idx_marketplace_status_posted ON marketplace_listings(status, posted_by);
   CREATE INDEX idx_jobs_assigned_status ON jobs(assigned_business_id, status);
   CREATE INDEX idx_order_bids_bidder_status ON order_bids(bidder_id, status);
   ```

### 🟢 **Low Priority (장기 개선)**

7. **전역 Realtime 서비스**
   - 앱 전체에서 하나의 Realtime 관리자 사용

8. **Materialized Views**
   - 자주 조회되는 통계를 뷰로 미리 계산

9. **Redis 캐싱 레이어**
   - 백엔드에 캐싱 추가

---

## 📈 예상 성능 개선 효과

| 작업 | 현재 로딩 시간 | 개선 후 | 개선율 |
|------|---------------|---------|--------|
| Dashboard 초기 로드 | ~3-5초 | ~1-2초 | 60% |
| OrderMarketplace | ~2-3초 | ~0.8-1.2초 | 50% |
| 이미지 로딩 (반복) | ~1-2초 | ~0.1-0.3초 | 85% |

**총 체감 성능 향상: 약 50-70%**

---

## 💡 즉시 적용 가능한 Quick Wins

### 1. OrderMarketplaceScreen 병렬화
```dart
// AS-IS
final bids = await _api.get('/market/bids...');
final listings = await _market.listListings(...);

// TO-BE
final results = await Future.wait([
  _api.get('/market/bids...'),
  _market.listListings(...),
]);
```

### 2. Count 쿼리 최적화
```dart
// AS-IS
.select('*').count(CountOption.exact);

// TO-BE
.select('id', const FetchOptions(count: CountOption.exact, head: true));
```

### 3. 광고 배너 캐싱
```dart
// 이미 CachedNetworkImage 사용 중 - Good! ✅
```

---

## 🎯 다음 단계

이 분석을 바탕으로 어떤 개선 작업부터 시작하시겠습니까?

1. **OrderMarketplaceScreen 병렬 로딩** (가장 빠른 효과)
2. **Dashboard 쿼리 최적화** (체감 성능 향상 큼)
3. **데이터베이스 인덱스 추가** (장기적 개선)
4. **전체 최적화 패키지** (모든 개선 사항 적용)

어떤 것을 먼저 진행할까요?


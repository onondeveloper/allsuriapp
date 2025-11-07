# 오더 입찰 시스템 프로세스

## 📋 전체 흐름

### 1️⃣ **오더 생성 (사업자 A)**
```
사업자 A → "공사 만들기" → 정보 입력 → "오더로 올리기"
```

**DB 변경:**
- `jobs` 테이블에 INSERT
  - `status: 'created'`
  - `owner_business_id: A의 ID`
- `marketplace_listings` 테이블에 자동 INSERT (trigger)
  - `status: 'created'`
  - `posted_by: A의 ID`
  - `bid_count: 0`

---

### 2️⃣ **입찰 (사업자 B, C, D)**
```
사업자 B → 오더 마켓 → 오더 상세 → "오더 잡기" 클릭
```

**API 호출:**
```
POST /api/market/listings/:id/bid
Body: { businessId: B의 ID, message: "이 오더를 맡고 싶습니다." }
```

**DB 변경:**
- `order_bids` 테이블에 INSERT
  - `listing_id: 오더 ID`
  - `bidder_id: B의 ID`
  - `status: 'pending'`
  - `message: "이 오더를 맡고 싶습니다."`
- `marketplace_listings.bid_count` 자동 증가 (trigger)
- `notifications` 테이블에 INSERT (사업자 A에게)
  - `type: 'new_bid'`
  - `title: "새로운 입찰"`
  - `body: "오더에 새로운 입찰이 들어왔습니다."`

**사용자 피드백:**
- 사업자 B: "입찰이 완료되었습니다! 오더를 만든 사업자의 승인을 기다리고 있어요~"
- 사업자 A: 알림 목록에 "새로운 입찰" 표시 + 기기 푸시 알림 (FCM 설정 시)

---

### 3️⃣ **입찰자 목록 확인 (사업자 A)**
```
사업자 A → 알림 클릭 → 입찰자 목록 화면
```

**API 호출:**
```
GET /api/market/listings/:id/bids
```

**응답:**
```json
[
  {
    "id": "bid-uuid-1",
    "bidder_id": "B의 ID",
    "status": "pending",
    "message": "이 오더를 맡고 싶습니다.",
    "created_at": "2025-11-07T...",
    "bidder": {
      "businessname": "B 사업자",
      "avatar_url": "...",
      "estimates_created_count": 10,
      "jobs_accepted_count": 5
    }
  },
  {
    "id": "bid-uuid-2",
    "bidder_id": "C의 ID",
    "status": "pending",
    ...
  }
]
```

**화면 표시:**
- 각 입찰자의 프로필, 통계, 메시지
- "이 사업자 선택하기" 버튼

---

### 4️⃣ **입찰자 선택 (사업자 A)**
```
사업자 A → 입찰자 목록 → "이 사업자 선택하기" (사업자 B 선택)
```

**API 호출:**
```
POST /api/market/listings/:id/select-bidder
Body: { bidderId: B의 ID, ownerId: A의 ID }
```

**RPC 호출:**
```sql
SELECT select_bidder(
  p_listing_id := '오더 ID',
  p_bidder_id := 'B의 ID',
  p_owner_id := 'A의 ID'
);
```

**DB 변경 (RPC 내부):**

1. **권한 확인:**
   - `marketplace_listings.posted_by = A의 ID` 확인
   - 실패 시: `EXCEPTION '오더 소유자만 입찰자를 선택할 수 있습니다'`

2. **입찰 상태 변경:**
   ```sql
   UPDATE order_bids
   SET status = 'selected', updated_at = NOW()
   WHERE listing_id = '오더 ID' AND bidder_id = 'B의 ID';
   ```

3. **Trigger 실행 (`handle_bidder_selection`):**
   - `marketplace_listings` 업데이트:
     ```sql
     UPDATE marketplace_listings
     SET selected_bidder_id = 'B의 ID',
         status = 'assigned',
         claimed_by = 'B의 ID',
         claimed_at = NOW(),
         updatedat = NOW()
     WHERE id = '오더 ID';
     ```
   
   - 다른 입찰들 거절:
     ```sql
     UPDATE order_bids
     SET status = 'rejected', updated_at = NOW()
     WHERE listing_id = '오더 ID' 
       AND id != 'B의 입찰 ID'
       AND status = 'pending';
     ```
   
   - `jobs` 테이블 업데이트:
     ```sql
     UPDATE jobs
     SET assigned_business_id = 'B의 ID',
         status = 'assigned',
         updated_at = NOW()
     WHERE id = 'job_id';
     ```

4. **알림 생성 (Backend):**
   - 선택된 사업자 B:
     ```json
     {
       "userid": "B의 ID",
       "title": "오더 선택됨",
       "body": "오더에 선택되었습니다!",
       "type": "bid_selected"
     }
     ```
   
   - 거절된 사업자 C, D:
     ```json
     {
       "userid": "C의 ID",
       "title": "오더가 다른 사업자에게 이관되었습니다",
       "body": "오더가 다른 사업자에게 이관되었습니다. 다음 기회를 노려보시기 바랍니다.",
       "type": "bid_rejected"
     }
     ```

5. **채팅방 생성 (Backend):**
   ```sql
   INSERT INTO chat_rooms (id, listingid, jobid, participant_a, participant_b, ...)
   VALUES ('order_오더ID', '오더 ID', 'job_id', 'A의 ID', 'B의 ID', ...);
   
   INSERT INTO chat_messages (room_id, sender_id, content, type, ...)
   VALUES ('order_오더ID', 'A의 ID', '안녕하세요, 오더 관련 채팅방입니다', 'system', ...);
   ```

**사용자 피드백:**
- 사업자 A: "B 사업자 님이 선택되었습니다!"
- 사업자 B: 알림 목록에 "오더 선택됨" + 채팅방 활성화
- 사업자 C, D: 알림 목록에 "오더가 다른 사업자에게 이관되었습니다"

---

## 🔍 현재 발견된 문제

### ❌ **문제: `jobs.status` CHECK 제약 조건 위반**

**증상:**
```
ERROR: new row for relation "jobs" violates check constraint "jobs_status_check"
```

**원인:**
`order_bids_system.sql`의 `handle_bidder_selection()` 트리거 함수에서:
```sql
UPDATE jobs
SET status = 'in_progress'  -- ❌ 'in_progress'는 허용되지 않는 값
WHERE id = NEW.job_id;
```

**해결책:**
```sql
UPDATE jobs
SET status = 'assigned'  -- ✅ 'assigned'로 변경
WHERE id = NEW.job_id;
```

---

## ✅ 수정 방법

### 1. Supabase SQL Editor에서 실행:
```bash
database/fix_order_bids_jobs_status.sql
```

### 2. 수정 내용:
- `handle_bidder_selection()` 함수의 `jobs.status` 업데이트를 `'in_progress'` → `'assigned'`로 변경

---

## 📊 상태 전이도

### `marketplace_listings.status`:
```
created → assigned (입찰자 선택 시)
```

### `jobs.status`:
```
created → assigned (입찰자 선택 시)
```

### `order_bids.status`:
```
pending → selected (선택됨)
pending → rejected (다른 사업자가 선택됨)
pending → withdrawn (입찰자가 취소)
```

---

## 🧪 테스트 시나리오

### 시나리오 1: 정상 입찰 및 선택
1. ✅ 사업자 A가 오더 생성
2. ✅ 사업자 B, C가 입찰
3. ✅ 사업자 A가 B 선택
4. ✅ B는 "선택됨" 알림, C는 "거절됨" 알림
5. ✅ A-B 간 채팅방 생성
6. ✅ `jobs.status = 'assigned'`
7. ✅ `marketplace_listings.status = 'assigned'`

### 시나리오 2: 입찰 취소
1. ✅ 사업자 B가 입찰
2. ✅ 사업자 B가 입찰 취소
3. ✅ `order_bids.status = 'withdrawn'`
4. ✅ `marketplace_listings.bid_count` 감소

### 시나리오 3: 중복 입찰 방지
1. ✅ 사업자 B가 입찰
2. ❌ 사업자 B가 다시 입찰 시도
3. ✅ 409 Conflict: "이미 입찰하셨습니다"

---

## 🚀 다음 단계

1. ✅ `fix_order_bids_jobs_status.sql` 실행
2. ✅ Git commit & push
3. ✅ Netlify 배포 대기 (2-3분)
4. 🧪 Flutter Hot Restart 후 테스트


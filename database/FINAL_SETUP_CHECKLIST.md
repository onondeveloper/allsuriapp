# 🚨 최종 설정 체크리스트

## ✅ 이미 완료한 작업

- [x] 중복 RLS 정책 삭제
- [x] chat_rooms estimateid nullable 설정

## 🔧 추가로 실행해야 할 SQL

### 1️⃣ 사용자 통계 컬럼 추가 (필수!)

**문제**: 입찰자 정보에 "견적 올린 수", "완료 건 수"가 0으로 표시됨

**해결**: 다음 SQL 실행

```sql
-- database/add_user_stats_columns.sql 전체 내용 복사 & 실행
```

또는 간단 버전:

```sql
-- 컬럼 추가
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS estimates_created_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS jobs_accepted_count INTEGER DEFAULT 0;

-- 기존 데이터 업데이트
UPDATE public.users SET 
  estimates_created_count = (
    SELECT COUNT(*) FROM estimates WHERE businessid = users.id
  ),
  jobs_accepted_count = (
    SELECT COUNT(*) FROM jobs 
    WHERE assigned_business_id = users.id AND status = 'completed'
  )
WHERE role = 'business';
```

**확인**:
```sql
SELECT businessname, estimates_created_count, jobs_accepted_count
FROM users
WHERE role = 'business'
LIMIT 5;
```

### 2️⃣ Realtime 활성화 확인 (필수!)

**문제**: 공사 완료 시 원 사업자에게 실시간 알림이 안 감

**확인**:
```sql
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('marketplace_listings', 'order_bids', 'jobs');
```

**결과**: 3개 테이블 모두 나와야 함

**없으면 추가**:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE marketplace_listings;
ALTER PUBLICATION supabase_realtime ADD TABLE order_bids;
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
```

### 3️⃣ RLS 정책 최종 확인

```sql
-- marketplace_listings UPDATE 정책 (1개만 있어야 함)
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'marketplace_listings' AND cmd = 'UPDATE';

-- 결과: update_marketplace_listings 1개만
```

**2개 이상 나오면**:
```sql
DROP POLICY IF EXISTS upd_marketplace_listings ON public.marketplace_listings;
```

---

## 📱 앱 재시작

모든 SQL 실행 후:

1. **앱 완전 종료**
2. **다시 실행** (Hot Reload X)
3. **테스트 시작**

---

## 🧪 테스트 체크리스트

### ✅ Test 1: 공사 완료 → 알림 → 평점

**사업자 A (낙찰받은 사람)**:
```
[내 공사] → [진행 중] 탭 → [공사 완료] 버튼
```

**로그 확인**:
```
✅ marketplace_listings 업데이트 결과: 1개 행
✅ jobs 업데이트 결과: 1개 행
```

**사업자 B (오더 만든 사람)**:
```
1. 스낵바: "공사가 완료되었습니다! 확인 후 리뷰를 작성해주세요."
2. [내 오더 관리] → [진행 중] 탭
3. 상태: "완료 확인 대기" (보라색 배지)
4. [리뷰 작성] 버튼 (노란색)
```

### ✅ Test 2: 낙찰 → 채팅방 자동 열림

**사업자 B (오더 만든 사람)**:
```
1. [내 오더 관리] → 입찰이 있는 오더
2. [입찰자 보기 (N명)] 클릭
3. 사업자 선택 → [이 사업자 선택하기]
4. "선택 완료" 다이얼로그
5. [확인] 클릭
6. 자동으로 채팅방 화면 열림 ✅
```

**로그 확인**:
```
✅ [OrderBiddersScreen] 채팅방 생성 성공: [chat_room_id]
💬 [OrderBiddersScreen] 채팅방으로 이동: [chat_room_id]
```

### ✅ Test 3: 입찰자 통계 표시

**사업자 B (오더 만든 사람)**:
```
1. [내 오더 관리] → 입찰이 있는 오더
2. [입찰자 보기 (N명)] 클릭
```

**확인 사항**:
```
[입찰자 카드]
  [사업자 이름]
  ⭐ 견적 5건  ← 이게 0이 아니어야 함!
  ✅ 완료 3건  ← 이게 0이 아니어야 함!
  📍 활동 지역: 서울, 경기
  💼 전문 분야: 수도, 전기
```

---

## 🐛 여전히 문제가 있다면

### 문제 1: 공사 완료 후 알림이 안 옴

**확인**:
```sql
-- RLS 정책 개수
SELECT COUNT(*) 
FROM pg_policies 
WHERE tablename = 'marketplace_listings' AND cmd = 'UPDATE';
```

**결과가 2 이상이면**:
```sql
DROP POLICY IF EXISTS upd_marketplace_listings ON public.marketplace_listings;
```

**Realtime 확인**:
```sql
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
```

### 문제 2: 채팅방 생성 실패

**로그 확인**:
```
❌ [OrderBiddersScreen] 채팅방 생성 실패: PostgrestException...
```

**SQL 확인**:
```sql
SELECT column_name, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'chat_rooms' AND column_name = 'estimateid';

-- is_nullable이 'YES'여야 함
```

**NO라면**:
```sql
ALTER TABLE public.chat_rooms ALTER COLUMN estimateid DROP NOT NULL;
```

### 문제 3: 입찰자 통계가 0으로 표시

**원인**: 컬럼이 없거나 데이터가 없음

**확인**:
```sql
SELECT 
  id,
  businessname,
  estimates_created_count,
  jobs_accepted_count
FROM users
WHERE role = 'business'
LIMIT 5;
```

**컬럼이 없으면**:
```sql
-- database/add_user_stats_columns.sql 실행
```

---

## 📊 데이터 확인 쿼리

### 공사 완료 상태 확인
```sql
SELECT 
  ml.title,
  ml.status,
  ml.completed_by,
  j.status as job_status
FROM marketplace_listings ml
LEFT JOIN jobs j ON ml.jobid = j.id
WHERE ml.id = '[문제의 listing_id]';
```

### 채팅방 확인
```sql
SELECT * FROM chat_rooms
ORDER BY createdat DESC
LIMIT 5;
```

### 사용자 통계 확인
```sql
SELECT 
  businessname,
  estimates_created_count,
  jobs_accepted_count,
  (SELECT COUNT(*) FROM estimates WHERE businessid = users.id) as actual_estimates,
  (SELECT COUNT(*) FROM jobs WHERE assigned_business_id = users.id AND status = 'completed') as actual_jobs
FROM users
WHERE role = 'business'
LIMIT 5;
```

---

## ✅ 최종 확인

모든 SQL 실행 후:

- [ ] RLS 정책 1개만 확인
- [ ] Realtime 활성화 확인
- [ ] 사용자 통계 컬럼 확인
- [ ] chat_rooms estimateid nullable 확인
- [ ] 앱 완전 재시작
- [ ] 테스트 1: 공사 완료 → 알림
- [ ] 테스트 2: 낙찰 → 채팅방
- [ ] 테스트 3: 입찰자 통계

**모두 체크되면 완료!** 🎉


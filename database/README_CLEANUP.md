# 데이터베이스 정리 스크립트 가이드

테스트 데이터를 정리하고 사업자 계정만 유지하기 위한 SQL 스크립트 모음입니다.

## ⚠️ 주의사항

**프로덕션 환경에서는 절대 실행하지 마세요!**
- 이 스크립트들은 데이터를 영구적으로 삭제합니다
- 실행 전 반드시 데이터베이스 백업을 수행하세요
- 테스트 환경에서만 사용하세요

---

## 📁 파일 설명

### 1. `clean_test_data.sql` (안전 모드)
**추천**: 처음 사용하거나 신중하게 진행하고 싶을 때

```sql
-- 특징:
-- ✅ 트랜잭션으로 감싸져 있음
-- ✅ 수동 COMMIT/ROLLBACK 필요
-- ✅ 각 단계별 확인 가능
-- ✅ 삭제 전 데이터 확인
```

**사용법:**
1. Supabase SQL Editor에서 파일 내용 붙여넣기
2. 실행하여 삭제될 데이터 확인
3. 문제없으면 마지막에 `COMMIT;` 실행
4. 문제있으면 `ROLLBACK;` 실행

---

### 2. `clean_test_data_auto.sql` (자동 모드)
**빠른 정리**: 확신이 있을 때

```sql
-- 특징:
-- ⚡ 자동으로 COMMIT
-- ⚡ 한 번에 모든 데이터 삭제
-- ⚠️ 되돌릴 수 없음
```

**사용법:**
1. **백업 필수!**
2. Supabase SQL Editor에서 실행
3. 완료!

---

### 3. `clean_keep_specific_business.sql` (선택적 유지)
**세밀한 제어**: 특정 사업자만 유지하고 싶을 때

```sql
-- 특징:
-- 🎯 특정 사업자 계정만 선택적으로 유지
-- 🔍 삭제 전 미리보기 가능
-- ✅ 주석으로 실행 제어
```

**사용법:**
1. 파일 열기
2. "businesses_to_keep" 부분에서 유지할 사업자 조건 수정:
   ```sql
   AND (
       id = 'kakao:4479276246' 
       OR email = 'your-business@example.com'
       OR businessname = '테스트 업체'
   )
   ```
3. 먼저 실행하여 미리보기 확인
4. 주석 해제 후 실행

---

## 📋 삭제되는 데이터

다음 테이블의 데이터가 삭제됩니다:

1. **커뮤니티**
   - `community_comments` (댓글)
   - `community_posts` (게시글)

2. **마켓플레이스**
   - `marketplace_listings` (상품 리스팅)

3. **알림**
   - `notifications` (모든 알림)

4. **메시지/채팅**
   - `messages` (메시지)
   - `chat_rooms` (채팅방)

5. **작업/견적**
   - `jobs` (작업)
   - `estimates` (견적)
   - `orders` (주문)

6. **프로필**
   - `profile_media` (프로필 미디어)

7. **사용자**
   - `users` (사업자 제외)

---

## 🔒 유지되는 데이터

다음 사용자는 **삭제되지 않습니다**:
- `role = 'business'` (사업자 계정)
- 해당 사업자의 모든 연관 데이터

---

## 🚀 실행 방법

### Supabase SQL Editor 사용
1. Supabase Dashboard 접속
2. SQL Editor 이동
3. New query 생성
4. 원하는 스크립트 파일 내용 붙여넣기
5. Run 클릭

### psql CLI 사용
```bash
psql "postgresql://postgres:password@db.xxx.supabase.co:5432/postgres" < clean_test_data.sql
```

---

## 📊 실행 후 확인

삭제 후 남은 데이터를 확인하려면:

```sql
-- 남은 사용자 수
SELECT role, COUNT(*) 
FROM users 
GROUP BY role;

-- 사업자 목록
SELECT id, name, email, businessname, businessstatus
FROM users 
WHERE role = 'business'
ORDER BY created_at DESC;

-- 모든 테이블의 레코드 수
SELECT 
    (SELECT COUNT(*) FROM users) AS users,
    (SELECT COUNT(*) FROM jobs) AS jobs,
    (SELECT COUNT(*) FROM notifications) AS notifications,
    (SELECT COUNT(*) FROM community_posts) AS posts,
    (SELECT COUNT(*) FROM community_comments) AS comments;
```

---

## 🆘 문제 해결

### "테이블을 찾을 수 없습니다" 에러
일부 테이블이 아직 생성되지 않았을 수 있습니다. 해당 DELETE 문을 주석 처리하세요.

### "외래 키 제약 위반" 에러
스크립트의 삭제 순서가 맞지 않습니다. 자식 테이블부터 삭제되도록 순서를 조정하세요.

### 실수로 삭제했을 때
백업이 없다면 되돌릴 수 없습니다. 프로덕션 환경에서는 절대 실행하지 마세요!

---

## 💾 백업 방법

삭제 전 백업:

```bash
# Supabase CLI
supabase db dump -f backup_$(date +%Y%m%d_%H%M%S).sql

# 또는 pg_dump
pg_dump "postgresql://connection-string" > backup.sql
```

---

## ✅ 체크리스트

실행 전 확인:
- [ ] 테스트 환경인가?
- [ ] 백업을 완료했는가?
- [ ] 유지할 사업자 계정이 맞는가?
- [ ] 스크립트 내용을 검토했는가?
- [ ] 되돌릴 수 없다는 것을 인지했는가?

---

**마지막 경고**: 이 스크립트는 데이터를 영구적으로 삭제합니다! 🚨


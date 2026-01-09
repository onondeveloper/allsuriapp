# 🚨 긴급: 오더 생성 RLS 정책 수정 필요

## 📋 현재 문제

**증상**: "오더로 올리기" 클릭 시 다음 에러 발생:
```
PostgrestException: new row violates row-level security policy for table "marketplace_listings"
code: 42501, details: Unauthorized
```

**원인**: 
- 앱이 Supabase Auth 세션 없이 작동 (자체 AuthService 사용)
- `marketplace_listings` 테이블의 INSERT RLS 정책이 `auth.uid()`를 요구
- `auth.uid()`가 null이어서 INSERT 실패

## ✅ 즉시 해결 방법

### 1단계: Supabase SQL Editor 접속

1. [Supabase Dashboard](https://supabase.com/dashboard) 접속
2. 올수리 프로젝트 선택
3. 왼쪽 메뉴에서 **SQL Editor** 클릭

### 2단계: SQL 실행

아래 SQL을 복사하여 SQL Editor에 붙여넣고 **Run** 버튼 클릭:

```sql
-- ==========================================
-- marketplace_listings INSERT 정책 수정
-- anon 사용자(Supabase Auth 세션 없음)도 INSERT 가능하도록
-- ==========================================

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS ins_marketplace_listings ON public.marketplace_listings;

-- 새 INSERT 정책: anon 사용자도 INSERT 가능
-- (posted_by가 유효한 business 사용자인지만 확인)
CREATE POLICY ins_marketplace_listings ON public.marketplace_listings
FOR INSERT
TO authenticated, anon
WITH CHECK (
  -- posted_by가 승인된 사업자인지 확인
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = marketplace_listings.posted_by
    AND role = 'business'
    AND businessstatus = 'approved'
  )
);

SELECT '✅ marketplace_listings INSERT RLS 정책 업데이트 완료' AS status;
```

### 3단계: 결과 확인

SQL 실행 후 다음 메시지가 표시되어야 합니다:
```
✅ marketplace_listings INSERT RLS 정책 업데이트 완료
```

### 4단계: 앱에서 테스트

1. 앱에서 **Hot Restart** (터미널에서 `R` 입력)
2. 공사 만들기 → 오더로 올리기 다시 테스트

## 🔒 보안 설명

### 변경 전 (기존 정책)
```sql
WITH CHECK (
  posted_by::text = (auth.uid())::text  -- ❌ auth.uid() 필요
  AND EXISTS (...)
)
```
- `auth.uid()`가 있어야만 INSERT 가능
- Supabase Auth 세션 필수

### 변경 후 (새 정책)
```sql
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = marketplace_listings.posted_by
    AND role = 'business'
    AND businessstatus = 'approved'
  )
)
```
- `posted_by`가 승인된 사업자인지만 확인
- Supabase Auth 세션 불필요
- 여전히 승인된 사업자만 오더 생성 가능 (보안 유지)

## 🎯 왜 안전한가?

1. **posted_by 검증**: 유효한 사업자 ID만 허용
2. **businessstatus 확인**: 'approved' 상태인 사업자만 허용
3. **앱에서 검증**: AuthService에서 이미 로그인된 사용자만 오더 생성 가능
4. **무단 생성 방지**: 임의의 사용자 ID로는 생성 불가 (users 테이블 검증)

## 📊 다른 해결 방법 (참고용)

### 방법 1: RLS 수정 (추천) ⭐
- **장점**: 즉시 적용, 간단
- **단점**: SQL 실행 필요
- **보안**: 안전 (승인된 사업자만 가능)

### 방법 2: Backend API 사용
- **장점**: RLS 우회
- **단점**: Backend 서버 업데이트 필요, 현재 404 에러
- **보안**: 안전 (Backend에서 검증)

### 방법 3: Supabase Auth 세션 설정
- **장점**: 정석적인 방법
- **단점**: 복잡함, 로그인 플로우 변경 필요
- **보안**: 가장 안전

## 🚀 다음 단계

1. **SQL 실행** (5분)
2. **앱 Hot Restart** (10초)
3. **오더 생성 테스트** (1분)
4. **카카오톡 공유 확인** (10초)

---

**예상 소요 시간**: 5분  
**난이도**: ⭐ 쉬움 (SQL 복사 & 붙여넣기)


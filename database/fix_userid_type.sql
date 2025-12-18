-- ============================================
-- userid 컬럼 타입 확인 및 RLS 정책 수정
-- ============================================

-- 1. notifications 테이블의 userid 컬럼 타입 확인
SELECT 
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'notifications' 
  AND column_name = 'userid';

-- 2. 샘플 데이터 확인 (타입 보기)
SELECT 
    id,
    userid,
    pg_typeof(userid) as userid_type,
    title,
    type,
    createdat
FROM notifications
ORDER BY createdat DESC
LIMIT 5;

-- 3. users 테이블의 id 컬럼 타입 확인
SELECT 
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'users' 
  AND column_name = 'id';

-- ============================================
-- RLS 정책 수정 (타입 캐스팅 추가)
-- ============================================

-- 모든 기존 정책 삭제
DROP POLICY IF EXISTS "prod_insert" ON notifications;
DROP POLICY IF EXISTS "prod_select" ON notifications;
DROP POLICY IF EXISTS "prod_update" ON notifications;
DROP POLICY IF EXISTS "prod_delete" ON notifications;

-- RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- INSERT: 모든 인증 사용자
CREATE POLICY "prod_insert"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- SELECT: 자신의 알림만 (타입 캐스팅 추가)
CREATE POLICY "prod_select"
ON notifications
FOR SELECT
TO authenticated
USING (
    CASE 
        -- userid가 UUID 타입인 경우
        WHEN pg_typeof(userid)::text LIKE '%uuid%' THEN userid = auth.uid()
        -- userid가 TEXT 타입인 경우
        ELSE userid::uuid = auth.uid()
    END
);

-- UPDATE: 자신의 알림만 (타입 캐스팅 추가)
CREATE POLICY "prod_update"
ON notifications
FOR UPDATE
TO authenticated
USING (
    CASE 
        -- userid가 UUID 타입인 경우
        WHEN pg_typeof(userid)::text LIKE '%uuid%' THEN userid = auth.uid()
        -- userid가 TEXT 타입인 경우
        ELSE userid::uuid = auth.uid()
    END
)
WITH CHECK (
    CASE 
        -- userid가 UUID 타입인 경우
        WHEN pg_typeof(userid)::text LIKE '%uuid%' THEN userid = auth.uid()
        -- userid가 TEXT 타입인 경우
        ELSE userid::uuid = auth.uid()
    END
);

-- DELETE: 자신의 알림만 (타입 캐스팅 추가)
CREATE POLICY "prod_delete"
ON notifications
FOR DELETE
TO authenticated
USING (
    CASE 
        -- userid가 UUID 타입인 경우
        WHEN pg_typeof(userid)::text LIKE '%uuid%' THEN userid = auth.uid()
        -- userid가 TEXT 타입인 경우
        ELSE userid::uuid = auth.uid()
    END
);

-- 정책 확인
SELECT policyname, cmd, permissive, roles
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;


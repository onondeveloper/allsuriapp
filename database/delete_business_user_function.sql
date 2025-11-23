-- 기존 함수 삭제
DROP FUNCTION IF EXISTS delete_user_cascade(UUID);
DROP FUNCTION IF EXISTS delete_business_user(UUID);

-- 수정된 사용자 삭제 함수 (올바른 컬럼명 사용)
CREATE OR REPLACE FUNCTION delete_user_cascade(user_id_to_delete UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_counts JSON;
  estimates_count INT := 0;
  bids_count INT := 0;
  listings_count INT := 0;
  jobs_count INT := 0;
  chats_count INT := 0;
  notifications_count INT := 0;
  comments_count INT := 0;
  posts_count INT := 0;
BEGIN
  -- 1. 견적 삭제 (estimates 테이블의 실제 컬럼명 확인)
  -- businessid, customerid가 아닌 business_id, customer_id일 수 있음
  BEGIN
    DELETE FROM estimates 
    WHERE business_id = user_id_to_delete OR customer_id = user_id_to_delete;
    GET DIAGNOSTICS estimates_count = ROW_COUNT;
  EXCEPTION WHEN undefined_column THEN
    -- 컬럼명이 다른 경우 시도
    DELETE FROM estimates 
    WHERE businessid = user_id_to_delete OR customerid = user_id_to_delete;
    GET DIAGNOSTICS estimates_count = ROW_COUNT;
  END;
  
  -- 2. 입찰 삭제 (order_bids)
  BEGIN
    DELETE FROM order_bids WHERE business_id = user_id_to_delete;
    GET DIAGNOSTICS bids_count = ROW_COUNT;
  EXCEPTION WHEN undefined_column THEN
    DELETE FROM order_bids WHERE businessid = user_id_to_delete;
    GET DIAGNOSTICS bids_count = ROW_COUNT;
  END;
  
  -- 3. 마켓플레이스 리스팅 삭제
  DELETE FROM marketplace_listings 
  WHERE posted_by = user_id_to_delete OR claimed_by = user_id_to_delete;
  GET DIAGNOSTICS listings_count = ROW_COUNT;
  
  -- 4. 작업(jobs) 삭제
  BEGIN
    DELETE FROM jobs 
    WHERE business_id = user_id_to_delete 
       OR customer_id = user_id_to_delete 
       OR owner_business_id = user_id_to_delete
       OR assigned_business_id = user_id_to_delete;
    GET DIAGNOSTICS jobs_count = ROW_COUNT;
  EXCEPTION WHEN undefined_column THEN
    DELETE FROM jobs 
    WHERE businessid = user_id_to_delete 
       OR customerid = user_id_to_delete 
       OR owner_business_id = user_id_to_delete
       OR assigned_business_id = user_id_to_delete;
    GET DIAGNOSTICS jobs_count = ROW_COUNT;
  END;
  
  -- 5. 채팅 메시지 삭제
  BEGIN
    DELETE FROM chat_messages WHERE sender_id = user_id_to_delete;
  EXCEPTION WHEN undefined_table THEN
    NULL; -- 테이블이 없으면 건너뛰기
  END;
  
  -- 6. 채팅방 삭제
  BEGIN
    DELETE FROM chat_rooms 
    WHERE business_id = user_id_to_delete 
       OR customer_id = user_id_to_delete;
    GET DIAGNOSTICS chats_count = ROW_COUNT;
  EXCEPTION WHEN undefined_table THEN
    NULL; -- 테이블이 없으면 건너뛰기
  END;
  
  -- 7. 알림 삭제
  BEGIN
    DELETE FROM notifications WHERE userid = user_id_to_delete;
    GET DIAGNOSTICS notifications_count = ROW_COUNT;
  EXCEPTION WHEN undefined_column THEN
    DELETE FROM notifications WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS notifications_count = ROW_COUNT;
  END;
  
  -- 8. 커뮤니티 댓글 삭제
  BEGIN
    DELETE FROM community_comments WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS comments_count = ROW_COUNT;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;
  
  -- 9. 커뮤니티 게시글 삭제
  BEGIN
    DELETE FROM community_posts WHERE user_id = user_id_to_delete;
    GET DIAGNOSTICS posts_count = ROW_COUNT;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;
  
  -- 10. 마지막으로 사용자 삭제
  DELETE FROM users WHERE id = user_id_to_delete;
  
  -- 삭제된 항목 수 반환
  deleted_counts := json_build_object(
    'estimates', estimates_count,
    'bids', bids_count,
    'listings', listings_count,
    'jobs', jobs_count,
    'chats', chats_count,
    'notifications', notifications_count,
    'comments', comments_count,
    'posts', posts_count,
    'user_deleted', true
  );
  
  RETURN deleted_counts;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete user: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END;
$$;

-- 권한 부여
GRANT EXECUTE ON FUNCTION delete_user_cascade TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_cascade TO service_role;
GRANT EXECUTE ON FUNCTION delete_user_cascade TO anon;

-- 별칭 함수 (하위 호환성)
CREATE OR REPLACE FUNCTION delete_business_user(user_id_to_delete UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN delete_user_cascade(user_id_to_delete);
END;
$$;

GRANT EXECUTE ON FUNCTION delete_business_user TO authenticated;
GRANT EXECUTE ON FUNCTION delete_business_user TO service_role;
GRANT EXECUTE ON FUNCTION delete_business_user TO anon;

-- 사용 예시:
-- SELECT delete_user_cascade('user-uuid-here');
-- SELECT delete_business_user('user-uuid-here'); -- 하위 호환성

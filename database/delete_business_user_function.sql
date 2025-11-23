-- 사용자 삭제 함수 (CASCADE 삭제 포함)
-- 이 함수는 사용자 계정(사업자 또는 고객)과 관련된 모든 데이터를 안전하게 삭제합니다

CREATE OR REPLACE FUNCTION delete_user_cascade(user_id_to_delete UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_counts JSON;
  estimates_count INT;
  bids_count INT;
  listings_count INT;
  jobs_count INT;
  chats_count INT;
  notifications_count INT;
BEGIN
  -- 1. 견적 삭제 (사업자가 작성한 견적 또는 고객이 요청한 견적)
  DELETE FROM estimates WHERE businessid = user_id_to_delete OR customerid = user_id_to_delete;
  GET DIAGNOSTICS estimates_count = ROW_COUNT;
  
  -- 2. 입찰 삭제 (사업자가 한 입찰)
  DELETE FROM order_bids WHERE businessid = user_id_to_delete;
  GET DIAGNOSTICS bids_count = ROW_COUNT;
  
  -- 3. 마켓플레이스 리스팅 삭제 (등록한 것 또는 claimed한 것)
  DELETE FROM marketplace_listings WHERE posted_by = user_id_to_delete OR claimed_by = user_id_to_delete;
  GET DIAGNOSTICS listings_count = ROW_COUNT;
  
  -- 4. 작업(jobs) 삭제 (사업자가 작성한 것 또는 고객이 요청한 것)
  DELETE FROM jobs WHERE businessid = user_id_to_delete OR customerid = user_id_to_delete;
  GET DIAGNOSTICS jobs_count = ROW_COUNT;
  
  -- 5. 채팅 메시지 삭제
  DELETE FROM chat_messages WHERE sender_id = user_id_to_delete;
  
  -- 6. 채팅방 삭제 (참여자로 있는 경우)
  DELETE FROM chat_rooms 
  WHERE business_id = user_id_to_delete 
     OR customer_id = user_id_to_delete;
  GET DIAGNOSTICS chats_count = ROW_COUNT;
  
  -- 7. 알림 삭제
  DELETE FROM notifications WHERE userid = user_id_to_delete;
  GET DIAGNOSTICS notifications_count = ROW_COUNT;
  
  -- 8. FCM 토큰 삭제 (있는 경우)
  -- fcm_tokens 테이블이 있다면 여기에 추가
  
  -- 9. 커뮤니티 게시글/댓글 삭제 (있는 경우)
  DELETE FROM community_comments WHERE user_id = user_id_to_delete;
  DELETE FROM community_posts WHERE user_id = user_id_to_delete;
  
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
    'user_deleted', true
  );
  
  RETURN deleted_counts;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete user: %', SQLERRM;
END;
$$;

-- 함수 실행 권한 부여
GRANT EXECUTE ON FUNCTION delete_user_cascade TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_cascade TO service_role;

-- 하위 호환성을 위한 별칭 함수 생성
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

-- 사용 예시:
-- SELECT delete_user_cascade('user-uuid-here');
-- SELECT delete_business_user('user-uuid-here'); -- 하위 호환성

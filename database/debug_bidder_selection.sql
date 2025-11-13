-- 입찰자 선택 후 데이터 확인
-- Supabase SQL Editor에서 실행

-- 1. 최근 선택된 입찰 확인
SELECT 
  ob.id,
  ob.listing_id,
  ob.bidder_id,
  ob.status,
  ob.created_at,
  ml.title as order_title,
  ml.posted_by as owner_id,
  ml.status as listing_status
FROM order_bids ob
JOIN marketplace_listings ml ON ob.listing_id = ml.id
WHERE ob.status = 'selected'
ORDER BY ob.updated_at DESC
LIMIT 5;

-- 2. 최근 생성된 채팅방 확인
SELECT 
  id,
  participant_a,
  participant_b,
  listingid,
  jobid,
  createdat,
  active
FROM chat_rooms
ORDER BY createdat DESC
LIMIT 10;

-- 3. 최근 알림 확인
SELECT 
  id,
  userid,
  title,
  body,
  type,
  jobid,
  isread,
  createdat
FROM notifications
ORDER BY createdat DESC
LIMIT 20;

-- 4. 특정 사용자의 알림 확인 (user ID를 아래에 입력)
-- SELECT * FROM notifications WHERE userid = '7cdd586f-e527-46a8-a4a1-db9ed4812248' ORDER BY createdat DESC LIMIT 10;
-- SELECT * FROM notifications WHERE userid = '23ef82c9-5962-4542-9996-b54aa98615ab' ORDER BY createdat DESC LIMIT 10;

-- 5. chat_messages 테이블 확인
SELECT 
  room_id,
  sender_id,
  content,
  type,
  createdat
FROM chat_messages
ORDER BY createdat DESC
LIMIT 10;


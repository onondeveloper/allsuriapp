-- order_bids 테이블 컬럼 구조 확인
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'order_bids'
ORDER BY ordinal_position;


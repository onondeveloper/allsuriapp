class AwsConfig {
  static const String region = 'ap-northeast-2';  // AWS 리전
  static const String endpoint = 'https://dynamodb.ap-northeast-2.amazonaws.com';  // DynamoDB 엔드포인트
  
  // Cognito 설정
  static const String userPoolId = 'ap-northeast-2_Y4nMNkGCG';
  static const String clientId = '558bbhibe0bctrm71r8k8fkcnf';
  static const String identityPoolId = 'ap-northeast-2:0290235f-5462-432b-89cb-c52d1776a7e5';
  
  // DynamoDB 테이블 이름
  static const String ordersTable = 'Orders';
  static const String estimatesTable = 'Estimates';
  static const String usersTable = 'Users';
  static const String chatsTable = 'Chats';

  // S3 설정
  static const String s3Bucket = 'allsuri-images';
  static const String s3Region = 'ap-northeast-2';
  static const String s3Endpoint = 'https://s3.ap-northeast-2.amazonaws.com';

  static const String accessKey = 'AKIAZQ3DPIQAUOT4ZNMV';
  static const String secretKey = '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';
} 
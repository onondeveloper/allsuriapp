import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:aws_common/aws_common.dart';
import '../models/order.dart'; // Order.STATUS_PENDING 사용을 위해 추가
import '../config/aws_config.dart';
import 'package:shared_aws_api/shared.dart';

class DynamoDBService {
  DynamoDBService(); // AuthService 의존성 완전히 제거

  List<Map<String, dynamic>> _mockOrders = [];
  List<Map<String, dynamic>> _mockEstimates = [];

  Future<List<Map<String, dynamic>>> getOrders() async {
    print("DynamoDBService: Getting mock orders...");
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {
        'id': 'mock_order_1',
        'customerId': 'mock_customer_1',
        'title': '배관 수리 요청',
        'description': '주방 배관에서 물이 새고 있습니다.',
        'address': '서울시 강남구',
        'visitDate': DateTime.now().toIso8601String(),
        'status': Order.STATUS_PENDING,
        'createdAt': DateTime.now().toIso8601String(),
        'images': [],
        'estimatedPrice': 15000.0,
      },
      {
        'id': 'mock_order_2',
        'customerId': 'mock_customer_1',
        'title': '전기 수리 요청',
        'description': '콘센트에서 불이 나고 있습니다.',
        'address': '서울시 서초구',
        'visitDate': DateTime.now().toIso8601String(),
        'status': Order.STATUS_IN_PROGRESS,
        'createdAt': DateTime.now().toIso8601String(),
        'images': [],
        'estimatedPrice': 30000.0,
      },
      {
        'id': 'mock_order_3',
        'customerId': 'mock_customer_1',
        'title': '에어컨 수리 요청',
        'description': '에어컨이 작동하지 않습니다.',
        'address': '서울시 송파구',
        'visitDate': DateTime.now().toIso8601String(),
        'status': Order.STATUS_COMPLETED,
        'createdAt': DateTime.now().toIso8601String(),
        'images': [],
        'estimatedPrice': 50000.0,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> listOrders({String? customerId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (customerId != null) {
      return _mockOrders.where((o) => o['customerId'] == customerId).toList();
    }
    return _mockOrders;
  }

  Future<void> putItem(String tableName, Map<String, AttributeValue> item) async {
    print("DynamoDBService: Mock putItem called for $tableName");
    await Future.delayed(const Duration(milliseconds: 100)); // 로딩 시뮬레이션
    // 실제 작업 없음
  }

  Future<void> updateItem(String tableName, Map<String, AttributeValue> item) async {
    print("DynamoDBService: Mock updateItem called for $tableName");
    await Future.delayed(const Duration(milliseconds: 100)); // 로딩 시뮬레이션
    // 실제 작업 없음
  }

  Future<void> deleteItem(String tableName, Map<String, AttributeValue> key) async {
    print("DynamoDBService: Mock deleteItem called for $tableName with key $key");
    await Future.delayed(const Duration(milliseconds: 100)); // 로딩 시뮬레이션
    // 실제 작업 없음
  }

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _mockOrders.add(orderData);
  }

  Future<void> updateOrder(Map<String, dynamic> orderData) async {
    print("DynamoDBService: Mock updateOrder called with $orderData");
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> deleteOrder(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _mockOrders.removeWhere((o) => o['id'] == orderId);
  }

  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    print("DynamoDBService: Getting mock users by role: $role");
    await Future.delayed(const Duration(milliseconds: 500));
    if (role == "business") {
      return [
        {
          'id': 'mock_business_1',
          'email': 'business1@example.com',
          'name': '테스트 사업자1',
          'role': 'business',
          'businessName': '올수리 파트너스1',
          'businessLicense': '111-11-11111',
          'phoneNumber': '010-1111-1111',
          'address': '서울시 강남구 테헤란로',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        {
          'id': 'mock_business_2',
          'email': 'business2@example.com',
          'name': '테스트 사업자2',
          'role': 'business',
          'businessName': '올수리 파트너스2',
          'businessLicense': '222-22-22222',
          'phoneNumber': '010-2222-2222',
          'address': '서울시 서초구 서초동',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
        {
          'id': 'mock_business_3',
          'email': 'business3@example.com',
          'name': '테스트 사업자3',
          'role': 'business',
          'businessName': '올수리 파트너스3',
          'businessLicense': '333-33-33333',
          'phoneNumber': '010-3333-3333',
          'address': '서울시 송파구 잠실동',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
        },
      ];
    } else {
      return [];
    }
  }

  void resetMockEstimates() {
    _mockEstimates.clear();
  }

  Future<List<Map<String, dynamic>>> listEstimates(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockEstimates.where((e) => e['orderId'] == orderId).toList();
  }

  Future<void> createEstimate(Map<String, dynamic> estimateData) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _mockEstimates.add(estimateData);
  }
} 
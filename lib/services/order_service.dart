import 'package:flutter/foundation.dart';
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:shared_aws_api/shared.dart';
import 'dart:math' show min;
import '../config/aws_config.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import 'dynamodb_service.dart';

class OrderService extends ChangeNotifier {
  final AuthService _authService;
  final DynamoDBService _dynamoDBService;
  late DynamoDB _dynamoDB;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  // 테스트용 Mock 데이터
  static final List<Order> _mockOrders = [];

  OrderService(this._authService, {DynamoDBService? dynamoDBService})
      : _dynamoDBService = dynamoDBService ?? DynamoDBService();

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _updateDynamoDBClient() {
    if (_authService.credentials == null) {
      print('Warning: AWS credentials are null during client update');
      return;
    }
    
    _dynamoDB = DynamoDB(
      region: AwsConfig.region,
      credentials: _authService.credentials,
      endpointUrl: AwsConfig.endpoint,
    );
  }

  Future<bool> _isTableActive(String tableName) async {
    try {
      final tableDescription = await _dynamoDB.describeTable(
        tableName: tableName,
      );
      return tableDescription.table?.tableStatus == TableStatus.active;
    } catch (e) {
      return false;
    }
  }

  Future<void> _waitForTableStatus(String tableName, TableStatus expectedStatus) async {
    bool isStatusReached = false;
    int attempts = 0;
    const maxAttempts = 30;
    const delaySeconds = 2;

    while (!isStatusReached && attempts < maxAttempts) {
      try {
        final tableDescription = await _dynamoDB.describeTable(
          tableName: tableName,
        );
        
        if (tableDescription.table?.tableStatus == expectedStatus) {
          isStatusReached = true;
          print('Table $tableName reached status: $expectedStatus');
        } else {
          print('Waiting for table $tableName to reach status $expectedStatus. Current status: ${tableDescription.table?.tableStatus}');
          await Future.delayed(Duration(seconds: delaySeconds));
          attempts++;
        }
      } catch (e) {
        if (expectedStatus == TableStatus.active) {
          print('Table not found or error checking status: $e');
          await Future.delayed(Duration(seconds: delaySeconds));
          attempts++;
        } else {
          // If we're waiting for table deletion and get a ResourceNotFoundException,
          // consider it as success
          if (e.toString().contains('ResourceNotFoundException')) {
            isStatusReached = true;
            print('Table $tableName has been deleted');
          } else {
            print('Error checking table status: $e');
            await Future.delayed(Duration(seconds: delaySeconds));
            attempts++;
          }
        }
      }
    }

    if (!isStatusReached) {
      throw Exception('Timeout waiting for table $tableName to reach status $expectedStatus');
    }
  }

  Future<void> _ensureTableExists() async {
    try {
      if (_dynamoDB == null) {
        throw Exception('DynamoDB client not initialized');
      }

      // 테이블 존재 여부 확인
      bool tableExists = false;
      try {
        final tableDescription = await _dynamoDB.describeTable(
          tableName: AwsConfig.ordersTable,
        );
        if (tableDescription.table?.tableStatus == TableStatus.active) {
          print('Orders table already exists and is active');
          return;
        }
        tableExists = true;
      } catch (e) {
        if (!e.toString().contains('ResourceNotFoundException')) {
          print('Error checking table existence: $e');
          rethrow;
        }
      }

      // 테이블이 존재하면 삭제
      if (tableExists) {
        try {
          print('Deleting existing orders table...');
          await _dynamoDB.deleteTable(
            tableName: AwsConfig.ordersTable,
          );
          
          // Wait for table deletion with exponential backoff
          int attempts = 0;
          const maxAttempts = 30;
          int delaySeconds = 1;

          while (attempts < maxAttempts) {
            try {
              await _dynamoDB.describeTable(
                tableName: AwsConfig.ordersTable,
              );
              print('Waiting for table deletion... (attempt ${attempts + 1}/$maxAttempts)');
              await Future.delayed(Duration(seconds: delaySeconds));
              delaySeconds = min(delaySeconds * 2, 10); // Exponential backoff with max 10 seconds
              attempts++;
            } catch (e) {
              if (e.toString().contains('ResourceNotFoundException')) {
                print('Table has been deleted successfully');
                break;
              }
              throw e;
            }
          }

          if (attempts >= maxAttempts) {
            throw Exception('Timeout waiting for table deletion');
          }

          // Add delay after deletion to avoid throttling
          await Future.delayed(const Duration(seconds: 10));
        } catch (e) {
          print('Error deleting table: $e');
          if (!e.toString().contains('ResourceNotFoundException')) {
            rethrow;
          }
        }
      }

      // Create table with retry logic
      int createAttempts = 0;
      const maxCreateAttempts = 5;
      int createDelaySeconds = 1;

      while (createAttempts < maxCreateAttempts) {
        try {
          print('Creating orders table (attempt ${createAttempts + 1}/$maxCreateAttempts)...');
          await _dynamoDB.createTable(
            tableName: AwsConfig.ordersTable,
            attributeDefinitions: [
              AttributeDefinition(
                attributeName: 'order_id',
                attributeType: ScalarAttributeType.s,
              ),
              AttributeDefinition(
                attributeName: 'customer_id',
                attributeType: ScalarAttributeType.s,
              ),
            ],
            keySchema: [
              KeySchemaElement(
                attributeName: 'order_id',
                keyType: KeyType.hash,
              ),
            ],
            globalSecondaryIndexes: [
              GlobalSecondaryIndex(
                indexName: 'CustomerIdIndex',
                keySchema: [
                  KeySchemaElement(
                    attributeName: 'customer_id',
                    keyType: KeyType.hash,
                  ),
                ],
                projection: Projection(
                  projectionType: ProjectionType.all,
                ),
                provisionedThroughput: ProvisionedThroughput(
                  readCapacityUnits: 5,
                  writeCapacityUnits: 5,
                ),
              ),
            ],
            provisionedThroughput: ProvisionedThroughput(
              readCapacityUnits: 5,
              writeCapacityUnits: 5,
            ),
          );
          break;
        } catch (e) {
          if (e.toString().contains('ThrottlingException')) {
            print('Rate limit exceeded, retrying after delay...');
            await Future.delayed(Duration(seconds: createDelaySeconds));
            createDelaySeconds = min(createDelaySeconds * 2, 30); // Exponential backoff with max 30 seconds
            createAttempts++;
            if (createAttempts >= maxCreateAttempts) {
              throw Exception('Failed to create table after $maxCreateAttempts attempts');
            }
            continue;
          }
          rethrow;
        }
      }

      // Wait for table to become active with exponential backoff
      int activeAttempts = 0;
      const maxActiveAttempts = 30;
      int activeDelaySeconds = 1;

      while (activeAttempts < maxActiveAttempts) {
        try {
          final tableDescription = await _dynamoDB.describeTable(
            tableName: AwsConfig.ordersTable,
          );
          
          if (tableDescription.table?.tableStatus == TableStatus.active) {
            print('Table is now active');
            break;
          }
          
          print('Waiting for table to become active. Current status: ${tableDescription.table?.tableStatus} (attempt ${activeAttempts + 1}/$maxActiveAttempts)');
          await Future.delayed(Duration(seconds: activeDelaySeconds));
          activeDelaySeconds = min(activeDelaySeconds * 2, 10); // Exponential backoff with max 10 seconds
          activeAttempts++;
        } catch (e) {
          print('Error checking table status: $e');
          await Future.delayed(Duration(seconds: activeDelaySeconds));
          activeDelaySeconds = min(activeDelaySeconds * 2, 10);
          activeAttempts++;
        }
      }

      if (activeAttempts >= maxActiveAttempts) {
        throw Exception('Timeout waiting for table to become active');
      }

      print('Orders table created and active');
    } catch (e, stackTrace) {
      print('Error ensuring table exists: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      rethrow;
    }
  }

  // New method for parsing estimated price
  double _parseEstimatedPrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is Map) {
      final nValue = value['n'];
      if (nValue != null) {
        return double.tryParse(nValue.toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

  String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final sValue = value['s'];
      if (sValue != null) return sValue.toString();
    }
    return '';
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (value is Map) {
      final sValue = value['s'];
      if (sValue != null) {
        try {
          return DateTime.parse(sValue.toString());
        } catch (e) {
          return DateTime.now();
        }
      }
    }
    return DateTime.now();
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) {
        if (item is String) return item;
        if (item is Map && item['s'] != null) {
          return item['s'].toString();
        }
        return '';
      }).where((item) => item.isNotEmpty).toList();
    }
    return [];
  }

  Map<String, AttributeValue> _convertOrderToItem(Order order) {
    try {
      if (order.id.isEmpty || order.customerId.isEmpty || order.title.isEmpty || 
          order.description.isEmpty || order.address.isEmpty) {
        throw Exception('Required order fields cannot be empty');
      }

      final Map<String, AttributeValue> item = {
        'order_id': AttributeValue(s: order.id),
        'customer_id': AttributeValue(s: order.customerId),
        'title': AttributeValue(s: order.title),
        'description': AttributeValue(s: order.description),
        'address': AttributeValue(s: order.address),
        'visit_date': AttributeValue(s: order.visitDate.toIso8601String()),
        'status': AttributeValue(s: order.status),
        'created_at': AttributeValue(s: order.createdAt.toIso8601String()),
        'image_urls': AttributeValue(ss: order.images),
        'estimated_price': AttributeValue(n: order.estimatedPrice.toString()),
      };

      if (order.technicianId != null && order.technicianId!.isNotEmpty) {
        item['technician_id'] = AttributeValue(s: order.technicianId!);
      }
      if (order.selectedEstimateId != null && order.selectedEstimateId!.isNotEmpty) {
        item['selected_estimate_id'] = AttributeValue(s: order.selectedEstimateId!);
      }

      print('Converted order to DynamoDB item: $item');
      return item;
    } catch (e, stackTrace) {
      print('Error converting order to item: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Order _convertItemToOrder(Map<String, AttributeValue> item) {
    try {
      final orderId = _parseString(item['order_id']);
      final customerId = _parseString(item['customer_id']);
      final title = _parseString(item['title']);
      final description = _parseString(item['description']);
      final address = _parseString(item['address']);
      final visitDateStr = _parseString(item['visit_date']);
      final status = _parseString(item['status']);
      final createdAtStr = _parseString(item['created_at']);

      final order = Order(
        id: orderId,
        customerId: customerId,
        title: title,
        description: description,
        address: address,
        visitDate: _parseDateTime(visitDateStr),
        status: status,
        images: _parseStringList(item['image_urls']),
        createdAt: _parseDateTime(createdAtStr),
        technicianId: _parseString(item['technician_id']),
        estimatedPrice: _parseEstimatedPrice(item['estimated_price']),
        selectedEstimateId: _parseString(item['selected_estimate_id']),
      );
      print('Successfully converted item to order: ${order.id}');
      return order;
    } catch (e, stackTrace) {
      print('Error converting item to order: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, AttributeValueUpdate> _convertOrderToUpdateAttributes(Order order) {
    try {
      final updates = <String, AttributeValueUpdate>{
        'status': AttributeValueUpdate(
          value: AttributeValue(s: order.status),
          action: AttributeAction.put,
        ),
      };

      if (order.technicianId != null) {
        updates['technician_id'] = AttributeValueUpdate(
          value: AttributeValue(s: order.technicianId!),
          action: AttributeAction.put,
        );
      }

      // Check if estimatedPrice is explicitly set (not default 0.0)
      if (order.estimatedPrice != 0.0) {
        updates['estimated_price'] = AttributeValueUpdate(
          value: AttributeValue(n: order.estimatedPrice.toString()),
          action: AttributeAction.put,
        );
      }

      if (order.selectedEstimateId != null) {
        updates['selected_estimate_id'] = AttributeValueUpdate(
          value: AttributeValue(s: order.selectedEstimateId!),
          action: AttributeAction.put,
        );
      }

      print('Converted order to update attributes: $updates');
      return updates;
    } catch (e, stackTrace) {
      print('Error converting order to update attributes: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // 주문 생성 (Mock 데이터 사용)
  Future<void> createOrder(Order order) async {
    try {
      print('OrderService.createOrder called with order: ${order.title}');
      print('Current mock orders count: ${_mockOrders.length}');
      // Mock 데이터에 추가
      _mockOrders.add(order);
      print('Mock order created successfully. Total orders: ${_mockOrders.length}');
      print('Added order details: ID=${order.id}, Title=${order.title}, CustomerId=${order.customerId}');
    } catch (e) {
      print('Error creating order: $e');
      throw e;
    }
  }

  // 주문 조회 (Mock 데이터 사용)
  Future<Order?> getOrder(String orderId) async {
    try {
      final order = _mockOrders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => throw Exception('Order not found'),
      );
      return order;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  // 고객의 주문 목록 조회 (Mock 데이터 사용)
  Future<List<Order>> getOrdersByCustomer(String customerId) async {
    try {
      final orders = _mockOrders.where((o) => o.customerId == customerId).toList();
      print('Found ${orders.length} orders for customer $customerId');
      return orders;
    } catch (e) {
      print('Error getting orders by customer: $e');
      return [];
    }
  }

  // 모든 주문 목록 조회 (Mock 데이터 사용)
  Future<List<Order>> getAllOrders() async {
    try {
      print('Found ${_mockOrders.length} total orders');
      return List.from(_mockOrders);
    } catch (e) {
      print('Error getting all orders: $e');
      return [];
    }
  }

  // 주문 상태별 조회 (Mock 데이터 사용)
  Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      final orders = _mockOrders.where((o) => o.status == status).toList();
      print('Found ${orders.length} orders with status $status');
      return orders;
    } catch (e) {
      print('Error getting orders by status: $e');
      return [];
    }
  }

  // 주문 업데이트 (Mock 데이터 사용)
  Future<void> updateOrder(Order order) async {
    try {
      final index = _mockOrders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _mockOrders[index] = order;
        print('Mock order updated successfully');
      } else {
        throw Exception('Order not found');
      }
    } catch (e) {
      print('Error updating order: $e');
      throw e;
    }
  }

  // 주문 삭제 (Mock 데이터 사용)
  Future<void> deleteOrder(String orderId) async {
    try {
      _mockOrders.removeWhere((o) => o.id == orderId);
      print('Mock order deleted successfully. Total orders: ${_mockOrders.length}');
    } catch (e) {
      print('Error deleting order: $e');
      throw e;
    }
  }

  // 견적 대기중인 주문 목록 조회 (Mock 데이터 사용)
  Future<List<Order>> getPendingOrders() async {
    try {
      final orders = _mockOrders.where((o) => o.status == 'pending' || o.status == 'PENDING').toList();
      print('Found ${orders.length} pending orders');
      return orders;
    } catch (e) {
      print('Error getting pending orders: $e');
      return [];
    }
  }

  Future<List<Order>> listOrders({String? customerId}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_authService.credentials == null) {
        throw Exception('AWS credentials not found');
      }
      
      _updateDynamoDBClient();

      if (_dynamoDB == null) {
        throw Exception('DynamoDB client not initialized');
      }

      print('Listing orders with customerId: $customerId');
      
      if (customerId != null) {
        // Use GSI for customer_id queries
        final response = await _dynamoDB.query(
          tableName: AwsConfig.ordersTable,
          indexName: 'CustomerIdIndex',
          keyConditions: {
            'customer_id': Condition(
              comparisonOperator: ComparisonOperator.eq,
              attributeValueList: [AttributeValue(s: customerId)],
            ),
          },
        );

        print('Query response: ${response.items}');
        if (response.items == null) {
          print('No orders found for customer: $customerId');
          _orders = [];
          return _orders;
        }

        _orders = response.items!
            .map((item) => _convertItemToOrder(item))
            .toList();
      } else {
        // Scan all orders if no customerId provided
        final response = await _dynamoDB.scan(
          tableName: AwsConfig.ordersTable,
        );

        print('Scan response: ${response.items}');
        if (response.items == null) {
          print('No orders found');
          _orders = [];
          return _orders;
        }

        _orders = response.items!
            .map((item) => _convertItemToOrder(item))
            .toList();
      }

      print('Found ${_orders.length} orders');
      _error = null;
      return _orders;
    } catch (e, stackTrace) {
      print('Error listing orders: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrderFromDynamoDBService(Order order) async {
    try {
      final item = {
        'id': AttributeValue(s: order.id),
        'customer_id': AttributeValue(s: order.customerId),
        'title': AttributeValue(s: order.title),
        'description': AttributeValue(s: order.description),
        'address': AttributeValue(s: order.address),
        'visit_date': AttributeValue(s: order.visitDate.toIso8601String()),
        'status': AttributeValue(s: order.status),
        'created_at': AttributeValue(s: order.createdAt.toIso8601String()),
        'images': AttributeValue(l: order.images.map((e) => AttributeValue(s: e)).toList()),
        'estimated_price': AttributeValue(n: order.estimatedPrice.toString()),
      };

      if (order.technicianId != null) {
        item['technician_id'] = AttributeValue(s: order.technicianId!);
      }

      if (order.selectedEstimateId != null) {
        item['selected_estimate_id'] = AttributeValue(s: order.selectedEstimateId!);
      }

      await _dynamoDBService.updateItem('Orders', item);
    } catch (e) {
      print('Error updating order: $e');
      rethrow;
    }
  }
} 
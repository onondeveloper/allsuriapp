import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import '../config/aws_config.dart';
import '../models/estimate.dart';
import '../services/auth_service.dart';

class EstimateService {
  final AuthService _authService;
  late DynamoDB _dynamoDB;
  
  // 테스트용 Mock 데이터
  static final List<Estimate> _mockEstimates = [];

  EstimateService(this._authService) {
    _updateDynamoDBClient();
  }

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

  // 견적 생성 (Mock 데이터 사용)
  Future<void> createEstimate(Estimate estimate) async {
    try {
      print('Creating estimate: ${estimate.id}');
      // Mock 데이터에 추가
      _mockEstimates.add(estimate);
      print('Mock estimate created successfully. Total estimates: ${_mockEstimates.length}');
    } catch (e) {
      print('Error creating estimate: $e');
      throw e;
    }
  }

  // 견적 조회 (Mock 데이터 사용)
  Future<Estimate?> getEstimate(String estimateId) async {
    try {
      final estimate = _mockEstimates.firstWhere(
        (e) => e.id == estimateId,
        orElse: () => throw Exception('Estimate not found'),
      );
      return estimate;
    } catch (e) {
      print('Error getting estimate: $e');
      return null;
    }
  }

  // 주문에 대한 견적 목록 조회 (Mock 데이터 사용)
  Future<List<Estimate>> listEstimatesForOrder(String orderId) async {
    try {
      final estimates = _mockEstimates.where((e) => e.orderId == orderId).toList();
      print('Found ${estimates.length} estimates for order $orderId');
      return estimates;
    } catch (e) {
      print('Error listing estimates: $e');
      return [];
    }
  }

  // 기술자가 제출한 견적 목록 조회 (Mock 데이터 사용)
  Future<List<Estimate>> listEstimatesByTechnician(String technicianId) async {
    try {
      final estimates = _mockEstimates.where((e) => e.technicianId == technicianId).toList();
      print('Found ${estimates.length} estimates for technician $technicianId');
      return estimates;
    } catch (e) {
      print('Error listing estimates by technician: $e');
      return [];
    }
  }

  // 견적 수정 (Mock 데이터 사용)
  Future<void> updateEstimate(Estimate estimate) async {
    try {
      final index = _mockEstimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _mockEstimates[index] = estimate;
        print('Mock estimate updated successfully');
      } else {
        throw Exception('Estimate not found');
      }
    } catch (e) {
      print('Error updating estimate: $e');
      throw e;
    }
  }

  // 견적 상태 업데이트 (Mock 데이터 사용)
  Future<void> updateEstimateStatus(String estimateId, String status) async {
    try {
      final index = _mockEstimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final estimate = _mockEstimates[index];
        _mockEstimates[index] = estimate.copyWith(status: status);
        print('Mock estimate status updated to: $status');
      } else {
        throw Exception('Estimate not found');
      }
    } catch (e) {
      print('Error updating estimate status: $e');
      throw e;
    }
  }

  // 견적 삭제 (Mock 데이터 사용)
  Future<void> deleteEstimate(String estimateId) async {
    try {
      _mockEstimates.removeWhere((e) => e.id == estimateId);
      print('Mock estimate deleted successfully. Total estimates: ${_mockEstimates.length}');
    } catch (e) {
      print('Error deleting estimate: $e');
      throw e;
    }
  }

  // Estimate 객체를 DynamoDB Item으로 변환
  Map<String, AttributeValue> _convertEstimateToItem(Estimate estimate) {
    return {
      'estimate_id': AttributeValue(s: estimate.id),
      'order_id': AttributeValue(s: estimate.orderId),
      'technician_id': AttributeValue(s: estimate.technicianId),
      'price': AttributeValue(n: estimate.price.toString()),
      'description': AttributeValue(s: estimate.description),
      'estimated_days': AttributeValue(n: estimate.estimatedDays.toString()),
      'created_at': AttributeValue(s: estimate.createdAt.toIso8601String()),
      'status': AttributeValue(s: estimate.status),
    };
  }

  // DynamoDB Item을 Estimate 객체로 변환
  Estimate _convertItemToEstimate(Map<String, AttributeValue> item) {
    return Estimate(
      id: item['estimate_id']!.s!,
      orderId: item['order_id']!.s!,
      technicianId: item['technician_id']!.s!,
      price: double.parse(item['price']!.n!),
      description: item['description']!.s!,
      estimatedDays: int.parse(item['estimated_days']!.n!),
      createdAt: DateTime.parse(item['created_at']!.s!),
      status: item['status']!.s!,
    );
  }
} 
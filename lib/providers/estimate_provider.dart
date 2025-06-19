import 'package:flutter/foundation.dart';
import '../models/estimate.dart';
import '../services/dynamodb_service.dart';

class EstimateProvider with ChangeNotifier {
  final DynamoDBService _dbService;
  List<Estimate> _estimates = [];
  bool _isLoading = false;
  String? _error;

  EstimateProvider(this._dbService);

  List<Estimate> get estimates => _estimates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEstimates(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final items = await _dbService.listEstimates(orderId);
      _estimates = items.map((item) => Estimate.fromMap(item)).toList();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEstimatesForOrder(String orderId) async {
    print('EstimateProvider.loadEstimatesForOrder called for orderId: $orderId');
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Mock 데이터 사용 (AWS 인증 문제로 인해)
      await Future.delayed(const Duration(milliseconds: 500)); // 로딩 시뮬레이션
      
      // 해당 주문에 대한 mock 견적 데이터 생성
      _estimates = _generateMockEstimates(orderId);
      
      print('Loaded ${_estimates.length} estimates for order $orderId');
    } catch (e) {
      _error = e.toString();
      print('Error loading estimates: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  List<Estimate> _generateMockEstimates(String orderId) {
    // 주문 ID에 따라 다른 mock 데이터 생성
    final mockEstimates = [
      Estimate(
        id: '${orderId}_estimate_1',
        orderId: orderId,
        technicianId: '사업자 A',
        price: 150000.0,
        description: '전문적인 수리 서비스를 제공합니다. 10년 경력의 기술자가 직접 방문하여 정확한 진단과 수리를 진행합니다.',
        estimatedDays: 2,
        status: 'PENDING',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Estimate(
        id: '${orderId}_estimate_2',
        orderId: orderId,
        technicianId: '사업자 B',
        price: 120000.0,
        description: '합리적인 가격으로 빠른 수리 서비스를 제공합니다. 당일 방문 가능하며, 품질 보증을 제공합니다.',
        estimatedDays: 1,
        status: 'PENDING',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Estimate(
        id: '${orderId}_estimate_3',
        orderId: orderId,
        technicianId: '사업자 C',
        price: 180000.0,
        description: '프리미엄 수리 서비스입니다. 최고급 부품을 사용하며, 1년 무상 보증을 제공합니다.',
        estimatedDays: 3,
        status: 'PENDING',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
    
    return mockEstimates;
  }

  Future<void> addEstimate(Estimate estimate) async {
    print('EstimateProvider.addEstimate called');
    try {
      // Mock 데이터에 추가
      _estimates.add(estimate);
      notifyListeners();
      print('Estimate added successfully');
    } catch (e) {
      _error = e.toString();
      print('Error adding estimate: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> acceptEstimate(String estimateId) async {
    print('EstimateProvider.acceptEstimate called for estimateId: $estimateId');
    try {
      // 해당 견적을 선택된 상태로 변경
      final estimateIndex = _estimates.indexWhere((e) => e.id == estimateId);
      if (estimateIndex != -1) {
        // 모든 견적을 REJECTED로 변경
        for (int i = 0; i < _estimates.length; i++) {
          _estimates[i] = _estimates[i].copyWith(status: 'REJECTED');
        }
        
        // 선택된 견적만 SELECTED로 변경
        _estimates[estimateIndex] = _estimates[estimateIndex].copyWith(status: 'SELECTED');
        
        notifyListeners();
        print('Estimate accepted successfully');
      } else {
        throw Exception('견적을 찾을 수 없습니다');
      }
    } catch (e) {
      _error = e.toString();
      print('Error accepting estimate: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateEstimate(Estimate estimate) async {
    try {
      final index = _estimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _estimates[index] = estimate;
        notifyListeners();
        print('Estimate updated successfully');
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating estimate: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> deleteEstimate(String estimateId) async {
    try {
      _estimates.removeWhere((e) => e.id == estimateId);
      notifyListeners();
      print('Estimate deleted successfully');
    } catch (e) {
      _error = e.toString();
      print('Error deleting estimate: $e');
      notifyListeners();
      throw e;
    }
  }

  // 해당 사업자가 입찰한 모든 견적 반환
  List<Estimate> getEstimatesForTechnician(String technicianId) {
    return _estimates.where((e) => e.technicianId == technicianId).toList();
  }

  // 해당 사업자가 선정된(수락된) 견적만 반환
  List<Estimate> getSelectedEstimatesForTechnician(String technicianId) {
    return _estimates.where((e) => e.technicianId == technicianId && e.status == 'SELECTED').toList();
  }
} 
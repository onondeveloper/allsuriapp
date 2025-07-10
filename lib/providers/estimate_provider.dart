import 'package:flutter/foundation.dart';
import '../models/estimate.dart';
import '../services/auth_service.dart';

class EstimateProvider extends ChangeNotifier {
  final AuthService _authService;
  List<Estimate> _estimates = [];
  List<Estimate> _transferredEstimates = []; // 이관한 견적 목록
  bool _isLoading = false;
  String? _error;

  EstimateProvider(this._authService);

  List<Estimate> get estimates => _estimates;
  List<Estimate> get myEstimates => _estimates;
  List<Estimate> get transferredEstimates => _transferredEstimates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEstimates() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 임시 구현
      await Future.delayed(const Duration(milliseconds: 500));
      _estimates = [
        Estimate(
          id: '1',
          orderId: 'order1',
          technicianId: 'tech1',
          technicianName: '사업자1',
          price: 45000.0,
          description: '에어컨 필터 교체 및 가스 충전',
          estimatedDays: 1,
          status: 'PENDING',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          visitDate: DateTime.now().add(const Duration(days: 1)),
        ),
      ];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEstimate(Estimate estimate) async {
    try {
      _estimates.add(estimate);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addEstimate(Estimate estimate) async {
    try {
      _estimates.add(estimate);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadEstimates(String orderId) async {
    await fetchEstimates();
  }

  Future<void> loadMyEstimates() async {
    await fetchEstimates();
  }

  Future<void> updateEstimate(Estimate estimate) async {
    try {
      final index = _estimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _estimates[index] = estimate;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteEstimate(String estimateId) async {
    try {
      _estimates.removeWhere((estimate) => estimate.id == estimateId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Estimate> getEstimatesForTechnician(String technicianId) {
    return _estimates.where((estimate) => estimate.technicianId == technicianId).toList();
  }

  List<Estimate> getSelectedEstimatesForTechnician(String technicianId) {
    return _estimates.where((estimate) => 
      estimate.technicianId == technicianId && estimate.status == 'SELECTED'
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 이관한 견적 로드
  Future<void> loadTransferredEstimates() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 임시 구현 - 실제로는 API에서 이관한 견적을 가져와야 합니다
      await Future.delayed(const Duration(milliseconds: 500));
      _transferredEstimates = [
        Estimate(
          id: 'TRANSFER_1',
          orderId: 'order1',
          technicianId: 'tech2',
          technicianName: '영희가전',
          price: 45000.0,
          description: '에어컨 필터 교체 및 가스 충전',
          estimatedDays: 1,
          status: 'PENDING',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          visitDate: DateTime.now().add(const Duration(days: 1)),
          customerName: '김고객',
          customerPhone: '010-1234-5678',
          address: '서울시 강남구',
          isTransferEstimate: true,
        ),
        Estimate(
          id: 'TRANSFER_2',
          orderId: 'order2',
          technicianId: 'tech3',
          technicianName: '민수정비',
          price: 35000.0,
          description: '냉장고 수리',
          estimatedDays: 2,
          status: 'ACCEPTED',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          visitDate: DateTime.now().add(const Duration(days: 2)),
          customerName: '이고객',
          customerPhone: '010-9876-5432',
          address: '부산시 해운대구',
          isTransferEstimate: true,
        ),
      ];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 이관 견적 추가
  Future<void> addTransferredEstimate(Estimate estimate) async {
    try {
      _transferredEstimates.add(estimate);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 이관 견적 업데이트
  Future<void> updateTransferredEstimate(Estimate estimate) async {
    try {
      final index = _transferredEstimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _transferredEstimates[index] = estimate;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

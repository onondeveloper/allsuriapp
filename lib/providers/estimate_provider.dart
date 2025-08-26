import 'package:flutter/foundation.dart';
import '../models/estimate.dart';
import '../services/estimate_service.dart';

class EstimateProvider extends ChangeNotifier {
  final EstimateService _estimateService = EstimateService();
  List<Estimate> _estimates = [];
  List<Estimate> _transferredEstimates = []; // 이관한 견적 목록
  bool _isLoading = false;
  String? _error;

  List<Estimate> get estimates => _estimates;
  List<Estimate> get myEstimates => _estimates;
  List<Estimate> get transferredEstimates => _transferredEstimates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEstimates({String? orderId, String? businessId, String? status}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _estimates = await _estimateService.getEstimates(
        orderId: orderId,
        businessId: businessId,
        customerId: null,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> createEstimate(Estimate estimate) async {
    try {
      await _estimateService.createEstimate(estimate);
      await loadEstimates(); // 목록 새로고침
      return estimate.id; // 견적 ID 반환
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEstimate(Estimate estimate) async {
    try {
      await _estimateService.updateEstimateStatus(estimate.id, estimate.status);
      await loadEstimates(); // 목록 새로고침
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteEstimate(String estimateId) async {
    try {
      await _estimateService.deleteEstimate(estimateId);
      await loadEstimates(); // 목록 새로고침
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Firebase에서 이관된 견적 데이터 가져오기
      final estimates = await _estimateService.getEstimates();
      _transferredEstimates = estimates.where((estimate) => 
        estimate.status == 'transferred'
      ).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // 누락된 메서드들 추가
  Future<List<Estimate>> fetchEstimates() async {
    await loadEstimates();
    return _estimates;
  }

  Future<void> loadMyEstimates() async {
    await loadEstimates();
  }

  Future<void> addEstimate(Estimate estimate) async {
    await createEstimate(estimate);
  }
}

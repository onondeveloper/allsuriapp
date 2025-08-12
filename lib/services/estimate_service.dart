import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estimate.dart';

class EstimateService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  List<Estimate> _estimates = [];
  bool _isLoading = false;

  List<Estimate> get estimates => _estimates;
  bool get isLoading => _isLoading;

  // 견적 목록 가져오기 (getEstimates 별칭)
  Future<List<Estimate>> getEstimates({
    String? businessId,
    String? customerId,
    String? orderId,
  }) async {
    await loadEstimates(businessId: businessId, customerId: customerId, orderId: orderId);
    return _estimates;
  }

  // 견적 목록 로드
  Future<void> loadEstimates({String? businessId, String? customerId, String? orderId}) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      var query = _sb.from('estimates').select();
      if (businessId != null) {
        query = query.eq('businessId', businessId);
      } else if (customerId != null) {
        query = query.eq('customerId', customerId);
      } else if (orderId != null) {
        query = query.eq('orderId', orderId);
      }
      final rows = await query.order('createdAt', ascending: false);
      _estimates = rows
          .map((r) => Estimate.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      print('견적 로드 오류: $e');
      _estimates = [];
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }

  // 안전한 notifyListeners 호출
  void _notifyListenersSafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  // 견적 생성
  Future<void> createEstimate(Estimate estimate) async {
    try {
      await _sb.from('estimates').insert(estimate.toMap());
      _estimates.add(estimate);
      _notifyListenersSafely();
    } catch (e) {
      print('견적 생성 오류: $e');
      rethrow;
    }
  }

  // 견적 업데이트
  Future<void> updateEstimate(Estimate estimate) async {
    try {
      await _sb.from('estimates').update(estimate.toMap()).eq('id', estimate.id);
      final index = _estimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _estimates[index] = estimate;
        _notifyListenersSafely();
      }
    } catch (e) {
      print('견적 업데이트 오류: $e');
      rethrow;
    }
  }

  // 견적 삭제
  Future<void> deleteEstimate(String estimateId) async {
    try {
      await _sb.from('estimates').delete().eq('id', estimateId);
      _estimates.removeWhere((estimate) => estimate.id == estimateId);
      _notifyListenersSafely();
    } catch (e) {
      print('견적 삭제 오류: $e');
      rethrow;
    }
  }

  // 견적 채택 (기존 awardEstimate 개선)
  Future<void> awardEstimate(String estimateId) async {
    try {
      final row = await _sb
          .from('estimates')
          .select()
          .eq('id', estimateId)
          .maybeSingle();

      await _sb
          .from('estimates')
          .update({
            'status': Estimate.STATUS_AWARDED,
            'awardedAt': DateTime.now().toIso8601String(),
          })
          .eq('id', estimateId);

      // 로컬 상태 업데이트
      final index = _estimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final updatedEstimate = _estimates[index].copyWith(
          status: Estimate.STATUS_AWARDED,
        );
        _estimates[index] = updatedEstimate;
        _notifyListenersSafely();
      }

      // 수수료 알림 등 사이드이펙트는 상위에서 별도 서비스로 처리
    } catch (e) {
      print('견적 채택 오류: $e');
      rethrow;
    }
  }

  // 견적 수락
  Future<void> acceptEstimate(String estimateId) async {
    try {
      final estimate = _estimates.firstWhere((e) => e.id == estimateId);
      final updatedEstimate = estimate.copyWith(
        status: Estimate.STATUS_ACCEPTED,
      );
      await updateEstimate(updatedEstimate);
    } catch (e) {
      print('견적 수락 오류: $e');
      rethrow;
    }
  }

  // 견적 거절 (새로 추가)
  Future<void> rejectEstimate(String estimateId) async {
    try {
      await _sb
          .from('estimates')
          .update({
            'status': Estimate.STATUS_REJECTED,
            'rejectedAt': DateTime.now().toIso8601String(),
          })
          .eq('id', estimateId);

      // 로컬 상태 업데이트
      final index = _estimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final updatedEstimate = _estimates[index].copyWith(
          status: Estimate.STATUS_REJECTED,
        );
        _estimates[index] = updatedEstimate;
        _notifyListenersSafely();
      }
    } catch (e) {
      print('견적 거절 오류: $e');
      rethrow;
    }
  }

  // 견적 상태 변경 (하위 호환성)
  Future<void> updateEstimateStatus(String estimateId, String status) async {
    try {
      final estimate = _estimates.firstWhere((e) => e.id == estimateId);
      final updatedEstimate = estimate.copyWith(status: status);
      await updateEstimate(updatedEstimate);
    } catch (e) {
      print('견적 상태 업데이트 오류: $e');
      rethrow;
    }
  }

  // 견적 완료
  Future<void> completeEstimate(String estimateId) async {
    await updateEstimateStatus(estimateId, Estimate.STATUS_COMPLETED);
  }

  // 견적 이관
  Future<void> transferEstimate({
    required String estimateId,
    required String newBusinessName,
    required String newPhoneNumber,
    required String reason,
    required String transferredBy,
  }) async {
    try {
      await _sb
          .from('estimates')
          .update({
            'businessName': newBusinessName,
            'businessPhone': newPhoneNumber,
            'transferredAt': DateTime.now().toIso8601String(),
            'transferredBy': transferredBy,
            'transferReason': reason,
            'status': 'transferred',
          })
          .eq('id', estimateId);

      await _sb.from('estimate_transfers').insert({
        'estimateId': estimateId,
        'newBusinessName': newBusinessName,
        'newPhoneNumber': newPhoneNumber,
        'reason': reason,
        'transferredBy': transferredBy,
        'transferredAt': DateTime.now().toIso8601String(),
      });

      // 로컬 상태 업데이트
      final index = _estimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final updatedEstimate = _estimates[index].copyWith(
          businessName: newBusinessName,
          businessPhone: newPhoneNumber,
          status: 'transferred',
        );
        _estimates[index] = updatedEstimate;
        _notifyListenersSafely();
      }
    } catch (e) {
      print('견적 이관 오류: $e');
      rethrow;
    }
  }

  // 주문별 견적 목록 조회 (하위 호환성)
  Future<List<Estimate>> listEstimatesForOrder(String orderId) async {
    return await getEstimates(orderId: orderId);
  }
} 
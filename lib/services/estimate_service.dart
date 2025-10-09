import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estimate.dart';
import 'package:allsuriapp/services/notification_service.dart';

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
      print('🔍 EstimateService.loadEstimates 시작');
      print('🔍 파라미터: businessId=$businessId, customerId=$customerId, orderId=$orderId');
      
      var query = _sb.from('estimates').select();
      if (businessId != null) {
        print('🔍 businessId로 필터링: $businessId');
        query = query.eq('businessId', businessId);
      } else if (customerId != null) {
        print('🔍 customerId로 필터링: $customerId');
        query = query.eq('customerId', customerId);
      } else if (orderId != null) {
        print('🔍 orderId로 필터링: $orderId');
        query = query.eq('orderId', orderId);
      }
      
      print('🔍 쿼리 실행 중...');
      // Supabase 테이블은 camelCase 사용
      final rows = await query.order('createdAt', ascending: false);
      
      print('🔍 DB에서 가져온 견적 행 수: ${rows.length}');
      
      _estimates = rows
          .map((r) => Estimate.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      
      print('🔍 변환된 견적 수: ${_estimates.length}');
      if (_estimates.isNotEmpty) {
        print('🔍 첫 번째 견적: ${_estimates.first.businessName} (금액: ${_estimates.first.amount})');
      }
    } catch (e) {
      print('❌ 견적 로드 오류: $e');
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
  Future<String> createEstimate(Estimate estimate) async {
    try {
      // DB 스키마(컬럼명)에 맞춘 입력 맵을 구성합니다.
      // 필수값 검증
      if (estimate.orderId.isEmpty) {
        throw Exception('주문 ID가 유효하지 않습니다.');
      }
      if (estimate.businessId.isEmpty) {
        throw Exception('사업자 ID가 유효하지 않습니다.');
      }

      // 'id'는 DB에서 자동 생성(uuid)되므로 전달하지 않습니다.
      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> insertData = {
        'orderId': estimate.orderId,
        'customername': (estimate.customerName.isEmpty ? '고객' : estimate.customerName),
        'businessid': estimate.businessId,
        'businessname': (estimate.businessName.isEmpty ? '사업자' : estimate.businessName),
        'businessphone': estimate.businessPhone,
        'equipmenttype': (estimate.equipmentType.isEmpty ? '기타' : estimate.equipmentType),
        'amount': estimate.amount,
        'description': estimate.description,
        'estimateddays': estimate.estimatedDays,
        'createdat': nowIso,
        'updatedAt': nowIso,
        'visitdate': estimate.visitDate.toIso8601String(),
        'status': estimate.status,
      };

      // 고객 ID가 있는 경우에만 설정 (빈 문자열로 넣지 않음 → 22P02 방지)
      if (estimate.customerId.isNotEmpty) {
        insertData['customerid'] = estimate.customerId;
      }

      final row = await _sb
          .from('estimates')
          .upsert(insertData, onConflict: 'orderId,businessid')
          .select('id, orderId, customerid, customername, businessid, businessname, businessphone, equipmenttype, amount, description, estimateddays, createdat, visitdate, status')
          .maybeSingle();

      String createdId = estimate.id;
      if (row != null) {
        final m = Map<String, dynamic>.from(row);
        createdId = (m['id']?.toString() ?? estimate.id);
        final created = Estimate(
          id: createdId,
          orderId: (m['orderId']?.toString() ?? estimate.orderId),
          customerId: (m['customerid']?.toString() ?? ''),
          customerName: (m['customername']?.toString() ?? estimate.customerName),
          businessId: (m['businessid']?.toString() ?? estimate.businessId),
          businessName: (m['businessname']?.toString() ?? estimate.businessName),
          businessPhone: (m['businessphone']?.toString() ?? estimate.businessPhone),
          equipmentType: (m['equipmenttype']?.toString() ?? estimate.equipmentType),
          amount: (m['amount'] is num ? (m['amount'] as num).toDouble() : estimate.amount),
          description: (m['description']?.toString() ?? estimate.description),
          estimatedDays: (m['estimateddays'] is num ? (m['estimateddays'] as num).toInt() : estimate.estimatedDays),
          createdAt: m['createdat'] != null ? DateTime.parse(m['createdat'].toString()) : estimate.createdAt,
          visitDate: m['visitdate'] != null ? DateTime.parse(m['visitdate'].toString()) : estimate.visitDate,
          status: (m['status']?.toString() ?? estimate.status),
        );
        _estimates.add(created);
      } else {
        // 삽입은 되었으나 row가 없으면 입력 값으로 추가
        _estimates.add(estimate);
      }
      _notifyListenersSafely();

      // 알림: 견적 제출 완료 (본인)
      final uid = _sb.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        try {
          await NotificationService().sendNotification(
            userId: uid,
            title: '견적 제출 완료',
            body: '제출한 견적이 저장되었습니다.',
          );
        } catch (_) {}
      }
      return createdId;
    } catch (e) {
      print('견적 생성 오류: $e');
      // 고유 제약 위반(이미 같은 주문에 동일 사업자가 제출한 경우) 가독성 향상
      final msg = e.toString();
      if (msg.contains('uq_estimates_order_business') || msg.contains('duplicate key value') || msg.contains('409')) {
        throw Exception('이미 이 요청에 제출한 견적이 있어 기존 견적을 업데이트했습니다.');
      }
      rethrow;
    }
  }

  // 견적 업데이트
  Future<void> updateEstimate(Estimate estimate) async {
    try {
      // DB 컬럼 스키마에 맞게 업데이트할 필드를 구성합니다.
      final updateData = {
        'orderId': estimate.orderId,
        'customerid': estimate.customerId,
        'customername': estimate.customerName,
        'businessid': estimate.businessId,
        'businessname': estimate.businessName,
        'businessphone': estimate.businessPhone,
        'equipmenttype': estimate.equipmentType,
        'amount': estimate.amount,
        'description': estimate.description,
        'estimateddays': estimate.estimatedDays,
        'status': estimate.status,
        'visitdate': estimate.visitDate.toIso8601String(),
        // updatedAt 컬럼이 있다면 자동 트리거나 별도 업데이트로 처리될 수 있음
      };
      await _sb.from('estimates').update(updateData).eq('id', estimate.id);
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

      // 알림: 견적 낙찰(본인)
      final uid = _sb.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        try {
          await NotificationService().sendNotification(
            userId: uid,
            title: '낙찰되었습니다',
            body: '제출한 견적이 낙찰로 선택되었습니다.',
          );
        } catch (_) {}
      }
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
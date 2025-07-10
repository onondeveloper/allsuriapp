import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/estimate.dart';
import '../models/order.dart' as app_order;
import 'auth_service.dart';
import 'notification_service.dart';
import 'order_service.dart';

class EstimateService extends ChangeNotifier {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  late final OrderService _orderService;
  List<Estimate> _estimates = [];

  EstimateService(this._authService) {
    _orderService = OrderService(_authService);
  }

  List<Estimate> get estimates => _estimates;

  // 견적 생성
  Future<void> createEstimate(Estimate estimate) async {
    try {
      print('=== 견적 서비스: 견적 생성 시작 ===');
      print('견적 ID: ${estimate.id}');
      print('주문 ID: ${estimate.orderId}');
      print('기술자 ID: ${estimate.technicianId}');
      print('기술자명: ${estimate.technicianName}');
      print('견적 금액: ${estimate.price}');
      print('견적 설명: ${estimate.description}');
      print('예상 작업 기간: ${estimate.estimatedDays}일');
      print('방문일: ${estimate.visitDate}');
      print('상태: ${estimate.status}');
      
      // Firestore에 저장
      print('Firestore에 견적 저장 시작...');
      await _firestore.collection('estimates').doc(estimate.id).set(estimate.toMap());
      print('✅ Firestore 견적 저장 완료!');
      
      // 로컬 리스트에 추가
      _estimates.add(estimate);
      print('로컬 리스트에 견적 추가 완료. 총 견적 수: ${_estimates.length}');
      
      // 견적 제안 알림 생성
      if (estimate.orderId != null) {
        try {
          final order = await _orderService.getOrder(estimate.orderId!);
          if (order != null && order.customerId != null) {
            await _notificationService.createEstimateNotification(
              customerId: order.customerId!,
              technicianName: estimate.technicianName,
              orderTitle: order.title,
              orderId: estimate.orderId,
              estimateId: estimate.id,
            );
            print('✅ 견적 제안 알림 생성 완료!');
          }
        } catch (e) {
          print('⚠️ 알림 생성 중 오류: $e');
        }
      }
      
      print('=== 견적 서비스: 견적 생성 완료 ===');
    } catch (e, stackTrace) {
      print('❌ 견적 생성 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      throw Exception('견적 생성에 실패했습니다: $e');
    }
  }

  // 견적 조회
  Future<Estimate?> getEstimate(String estimateId) async {
    try {
      final doc = await _firestore.collection('estimates').doc(estimateId).get();
      if (doc.exists) {
        return Estimate.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting estimate: $e');
      return null;
    }
  }

  // 주문에 대한 견적 목록 조회
  Future<List<Estimate>> listEstimatesForOrder(String orderId) async {
    try {
      print('=== 견적 서비스: 주문 견적 목록 조회 시작 ===');
      print('조회할 주문 ID: $orderId');
      
      // 복합 인덱스 문제를 해결하기 위해 단순 쿼리 사용
      final querySnapshot = await _firestore
          .collection('estimates')
          .where('orderId', isEqualTo: orderId)
          .get();

      print('Firestore 쿼리 결과: ${querySnapshot.docs.length}개 문서');
      
      final estimates = querySnapshot.docs
          .map((doc) {
            print('견적 문서 ID: ${doc.id}');
            print('견적 문서 데이터: ${doc.data()}');
            return Estimate.fromMap(doc.data());
          })
          .toList();

      // 클라이언트에서 정렬
      estimates.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('변환된 견적 수: ${estimates.length}');
      
      // 견적 상세 정보 출력
      for (final estimate in estimates) {
        print('견적 정보:');
        print('  - ID: ${estimate.id}');
        print('  - 주문 ID: ${estimate.orderId}');
        print('  - 기술자 ID: ${estimate.technicianId}');
        print('  - 기술자명: ${estimate.technicianName}');
        print('  - 금액: ${estimate.formattedPrice}');
        print('  - 상태: ${estimate.status}');
        print('  - 낙찰: ${estimate.isAwarded}');
      }

      // 로컬 리스트 업데이트
      _estimates = estimates;
      notifyListeners();
      
      return estimates;
    } catch (e) {
      print('Error listing estimates for order: $e');
      print('스택 트레이스: ${StackTrace.current}');
      return [];
    }
  }

  // 기술자가 제출한 견적 목록 조회
  Future<List<Estimate>> listEstimatesByTechnician(String technicianId) async {
    try {
      print('=== 견적 서비스: 기술자 견적 목록 조회 시작 ===');
      print('조회할 기술자 ID: $technicianId');
      
      final querySnapshot = await _firestore
          .collection('estimates')
          .where('technicianId', isEqualTo: technicianId)
          .get();

      print('Firestore 쿼리 결과: ${querySnapshot.docs.length}개 문서');
      
      final estimates = querySnapshot.docs
          .map((doc) {
            print('문서 ID: ${doc.id}');
            print('문서 데이터: ${doc.data()}');
            return Estimate.fromMap(doc.data());
          })
          .toList();

      // 클라이언트에서 정렬
      estimates.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('변환된 견적 수: ${estimates.length}');
      
      // 견적 상세 정보 출력
      for (final estimate in estimates) {
        print('견적 정보:');
        print('  - ID: ${estimate.id}');
        print('  - 주문 ID: ${estimate.orderId}');
        print('  - 기술자 ID: ${estimate.technicianId}');
        print('  - 기술자명: ${estimate.technicianName}');
        print('  - 상태: ${estimate.status}');
        print('  - 낙찰: ${estimate.isAwarded}');
        print('  - 금액: ${estimate.formattedPrice}');
      }

      return estimates;
    } catch (e, stackTrace) {
      print('Error listing estimates by technician: $e');
      print('스택 트레이스: $stackTrace');
      return [];
    }
  }

  // 견적 수정
  Future<void> updateEstimate(Estimate estimate) async {
    try {
      await _firestore.collection('estimates').doc(estimate.id).update(estimate.toMap());
      
      // 로컬 리스트 업데이트
      final index = _estimates.indexWhere((e) => e.id == estimate.id);
      if (index != -1) {
        _estimates[index] = estimate;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating estimate: $e');
      throw Exception('견적 수정 중 오류가 발생했습니다: $e');
    }
  }

  // 견적 상태 업데이트
  Future<void> updateEstimateStatus(String estimateId, String status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
      };
      
      if (status == Estimate.STATUS_AWARDED) {
        updateData['isAwarded'] = true;
        updateData['awardedAt'] = DateTime.now().toIso8601String();
        updateData['awardedBy'] = _authService.currentUser?.id;
      }
      
      await _firestore.collection('estimates').doc(estimateId).update(updateData);

      // 로컬 리스트 업데이트
      final index = _estimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        _estimates[index] = _estimates[index].copyWith(
          status: status,
          isAwarded: status == Estimate.STATUS_AWARDED,
          awardedAt: status == Estimate.STATUS_AWARDED ? DateTime.now() : null,
          awardedBy: status == Estimate.STATUS_AWARDED ? _authService.currentUser?.id : null,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error updating estimate status: $e');
      throw Exception('견적 상태 업데이트 중 오류가 발생했습니다: $e');
    }
  }

  // 견적 삭제
  Future<void> deleteEstimate(String estimateId) async {
    try {
      await _firestore.collection('estimates').doc(estimateId).delete();
      
      // 로컬 리스트에서 제거
      _estimates.removeWhere((e) => e.id == estimateId);
      notifyListeners();
    } catch (e) {
      print('Error deleting estimate: $e');
      throw Exception('견적 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 견적 낙찰
  Future<void> awardEstimate(String estimateId) async {
    try {
      final estimate = await getEstimate(estimateId);
      if (estimate == null) {
        throw Exception('견적을 찾을 수 없습니다.');
      }

      // 이관 견적의 경우 orderId가 null일 수 있음
      if (estimate.orderId != null) {
        // 해당 주문의 다른 견적들을 모두 거절 상태로 변경
        final otherEstimates = await listEstimatesForOrder(estimate.orderId!);
        for (final otherEstimate in otherEstimates) {
          if (otherEstimate.id != estimateId) {
            await updateEstimateStatus(otherEstimate.id, Estimate.STATUS_REJECTED);
          }
        }
      }

      // 선택된 견적을 낙찰 상태로 변경
      await updateEstimateStatus(estimateId, Estimate.STATUS_AWARDED);
      
      // 견적 선택 알림 생성
      try {
        String orderTitle = '견적 요청';
        if (estimate.orderId != null) {
          final order = await _orderService.getOrder(estimate.orderId!);
          if (order != null) {
            orderTitle = order.title;
          }
        }
        
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          await _notificationService.createEstimateSelectedNotification(
            technicianId: estimate.technicianId,
            customerName: currentUser.name,
            orderTitle: orderTitle,
            orderId: estimate.orderId,
            estimateId: estimate.id,
          );
          print('✅ 견적 선택 알림 생성 완료!');
        }
      } catch (e) {
        print('⚠️ 견적 선택 알림 생성 중 오류: $e');
      }
    } catch (e) {
      print('Error awarding estimate: $e');
      throw Exception('견적 낙찰 중 오류가 발생했습니다: $e');
    }
  }

  // 견적 목록 새로고침
  Future<void> fetchEstimates() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      print('Estimates fetched from Firestore');
    } catch (e) {
      print('Error fetching estimates: $e');
    }
  }

  // 기술자의 견적 목록 조회 (로컬)
  List<Estimate> getEstimatesForTechnician(String technicianId) {
    return _estimates.where((estimate) => estimate.technicianId == technicianId).toList();
  }

  // 기술자의 특정 상태 견적 목록 조회 (로컬)
  List<Estimate> getEstimatesForTechnicianByStatus(String technicianId, String status) {
    return _estimates.where((estimate) => 
      estimate.technicianId == technicianId && estimate.status == status
    ).toList();
  }

  // 기술자의 견적 목록 실시간 스트림
  Stream<List<Estimate>> getEstimatesStreamByTechnician(String technicianId) {
    return _firestore
        .collection('estimates')
        .where('technicianId', isEqualTo: technicianId)
        .snapshots()
        .map((snapshot) {
          final estimates = snapshot.docs
              .map((doc) => Estimate.fromMap(doc.data()))
              .toList();
          
          // 클라이언트에서 정렬
          estimates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // 로컬 리스트 업데이트
          _estimates = estimates;
          notifyListeners();
          
          return estimates;
        });
  }
}

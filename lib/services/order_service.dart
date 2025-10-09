import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../models/order.dart' as app_models;

class OrderService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  List<app_models.Order> _orders = [];
  bool _isLoading = false;

  List<app_models.Order> get orders => _orders;
  bool get isLoading => _isLoading;

  // 안전한 notifyListeners 호출
  void _notifyListenersSafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // 주문 목록 가져오기 (fetchOrders 별칭)
  Future<void> fetchOrders({String? customerId, String? status}) async {
    await loadOrders(customerId: customerId, status: status);
  }

  // 주문 목록 로드
  Future<void> loadOrders({String? customerId, String? status, String? sessionId}) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      // 환경 미설정 시 조용히 스킵 (디버그 장비에서 dart-define 누락 보호)
      if (SupabaseConfig.url.isEmpty || SupabaseConfig.anonKey.isEmpty) {
        print('⚠️ Supabase 설정이 비어 있어 주문 로드를 건너뜁니다');
        _orders = [];
        return;
      }
      print('🔍 OrderService.loadOrders 시작');
      print('🔍 파라미터: customerId=$customerId, status=$status, sessionId=$sessionId');
      
      var query = _sb.from('orders').select();

      if (customerId != null) {
        print('🔍 customerId로 필터링: $customerId');
        // Supabase 테이블은 camelCase 사용: customerId
        query = query.eq('customerId', customerId);
      }
      if (status != null) {
        print('🔍 status로 필터링: $status');
        query = query.eq('status', status);
      }
      if (sessionId != null) {
        print('🔍 sessionId로 필터링: $sessionId');
        // Supabase 테이블은 camelCase 사용: sessionId
        query = query.eq('sessionId', sessionId);
      }

      print('🔍 쿼리 실행 중...');
      // Supabase 테이블은 camelCase 사용: createdAt
      final rows = await query.order('createdAt', ascending: false);
      
      print('🔍 DB에서 가져온 행 수: ${rows.length}');
      
      _orders = rows
          .map((r) => app_models.Order.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      
      print('🔍 변환된 주문 수: ${_orders.length}');
      if (_orders.isNotEmpty) {
        print('🔍 첫 번째 주문: ${_orders.first.title} (고객: ${_orders.first.customerName}, 전화: ${_orders.first.customerPhone})');
      }
    } catch (e) {
      print('❌ 주문 로드 오류: $e');
      _orders = [];
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<List<app_models.Order>> getOrders({String? customerId, String? status}) async {
    await loadOrders(customerId: customerId, status: status);
    return _orders;
  }

  Future<app_models.Order?> getOrder(String orderId) async {
    try {
      final row = await _sb
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();
      if (row != null) {
        return app_models.Order.fromMap(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (e) {
      print('주문 조회 오류: $e');
      return null;
    }
  }

  Future<app_models.Order> createOrder(app_models.Order order) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      final inserted = await _sb.from('orders').insert(order.toMap()).select().single();
      final created = app_models.Order.fromMap(Map<String, dynamic>.from(inserted));
      _orders.add(created);
      return created;
    } catch (e) {
      print('주문 생성 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> updateOrder(app_models.Order order) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      if (order.id == null || order.id!.isEmpty) {
        throw ArgumentError('Order id is required for update');
      }
      await _sb.from('orders').update(order.toMap()).eq('id', order.id!);
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _orders[index] = order;
      }
    } catch (e) {
      print('주문 업데이트 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> deleteOrder(String orderId) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      await _sb.from('orders').delete().eq('id', orderId);
      _orders.removeWhere((order) => order.id == orderId);
    } catch (e) {
      print('주문 삭제 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }
} 
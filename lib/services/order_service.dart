import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      var query = _sb.from('orders').select();

      if (customerId != null) {
        query = query.eq('customerId', customerId);
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      if (sessionId != null) {
        query = query.eq('sessionId', sessionId);
      }

      final rows = await query.order('createdAt', ascending: false);
      _orders = rows
          .map((r) => app_models.Order.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      print('주문 로드 오류: $e');
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

  Future<void> createOrder(app_models.Order order) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      final inserted = await _sb.from('orders').insert(order.toMap()).select().single();
      final created = app_models.Order.fromMap(Map<String, dynamic>.from(inserted));
      _orders.add(created);
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
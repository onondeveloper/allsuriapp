import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart' as app_models;

class OrderService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
  Future<void> loadOrders({String? customerId, String? status}) async {
    _isLoading = true;
    _notifyListenersSafely();

    try {
      Query query = _firestore.collection('orders');
      
      if (customerId != null) {
        query = query.where('customerId', isEqualTo: customerId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      _orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return app_models.Order.fromMap(data);
      }).toList();
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
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return app_models.Order.fromMap(doc.data()!);
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
      await _firestore.collection('orders').doc(order.id).set(order.toMap());
      _orders.add(order);
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
      await _firestore.collection('orders').doc(order.id).update(order.toMap());
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
      await _firestore.collection('orders').doc(orderId).delete();
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
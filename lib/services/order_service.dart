import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../models/order.dart' as app_models;
import 'auth_service.dart';

class OrderService extends ChangeNotifier {
  final AuthService _authService;
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  List<app_models.Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  OrderService(this._authService);

  List<app_models.Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      _orders = querySnapshot.docs
          .map((doc) => app_models.Order.fromMap(doc.data()))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createOrder(app_models.Order order) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('=== OrderService.createOrder 시작 ===');
      print('주문 ID: ${order.id}');
      print('주문 제목: ${order.title}');
      print('고객 ID: ${order.customerId}');
      print('Firestore에 저장 시작...');
      
      // Firestore에 저장
      await _firestore.collection('orders').doc(order.id).set(order.toMap());
      print('Firestore 저장 완료!');
      
      // 로컬 리스트에 추가
      _orders.add(order);
      print('로컬 리스트에 추가 완료. 총 주문 수: ${_orders.length}');
      print('새 견적 요청 알림: ${order.toString()}');
      _isLoading = false;
      notifyListeners();
      print('=== OrderService.createOrder 완료 ===');
    } catch (e) {
      print('=== OrderService.createOrder 오류 ===');
      print('오류 내용: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw e;
    }
  }

  Future<app_models.Order?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return app_models.Order.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  Future<void> updateOrder(app_models.Order order) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Firestore 업데이트
      await _firestore.collection('orders').doc(order.id).update(order.toMap());
      
      // 로컬 리스트 업데이트
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _orders[index] = order;
      }
      print('Order updated: ${order.id}');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // 주문 상태 업데이트
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
      });

      // 로컬 리스트 업데이트
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(status: status);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating order status: $e');
      throw Exception('주문 상태 업데이트 중 오류가 발생했습니다: $e');
    }
  }

  // 대기 중인 견적 요청만 가져오기
  List<app_models.Order> getPendingOrders() {
    return _orders.where((order) => 
      order.status == app_models.Order.STATUS_PENDING || order.status == app_models.Order.STATUS_ESTIMATING
    ).toList();
  }

  // 특정 사용자의 견적 요청 가져오기
  List<app_models.Order> getOrdersByCustomer(String customerId) {
    return _orders.where((order) => order.customerId == customerId).toList();
  }

  // 주문 삭제
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
      
      // 로컬 리스트에서 제거
      _orders.removeWhere((o) => o.id == orderId);
      notifyListeners();
    } catch (e) {
      print('Error deleting order: $e');
      throw Exception('주문 삭제 중 오류가 발생했습니다: $e');
    }
  }
}

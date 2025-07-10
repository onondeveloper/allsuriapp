import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/auth_service.dart';

// Order 상태 상수
const String STATUS_PENDING = 'pending';
const String STATUS_IN_PROGRESS = 'in_progress';
const String STATUS_COMPLETED = 'completed';
const String STATUS_CANCELLED = 'cancelled';

class OrderProvider extends ChangeNotifier {
  final AuthService _authService;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  OrderProvider(this._authService);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 임시 구현 - 기존 주문들을 유지하면서 새로운 주문들만 추가
      await Future.delayed(const Duration(milliseconds: 500));
      if (_orders.isEmpty) {
        _orders = [
          Order(
            id: '1',
            title: '에어컨 수리',
            description: '에어컨이 작동하지 않습니다.',
            category: '에어컨',
            address: '서울시 강남구',
            visitDate: DateTime.now().add(const Duration(days: 1)),
            status: STATUS_PENDING,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            customerId: 'customer1',
            customerName: '홍길동',
            customerPhone: '010-1234-5678',
            images: [],
          ),
        ];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createOrder(Order order) async {
    try {
      _orders.add(order);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addOrder(Order order) async {
    try {
      print('Adding order: ${order.title} with customerId: ${order.customerId}');
      _orders.add(order);
      print('Total orders in provider: ${_orders.length}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    await fetchOrders();
  }

  Future<void> updateOrder(Order order) async {
    try {
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _orders[index] = order;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      _orders.removeWhere((order) => order.id == orderId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

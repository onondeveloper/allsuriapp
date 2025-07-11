import 'package:flutter/foundation.dart';
import '../models/order.dart' as app_models;
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService;
  List<app_models.Order> _orders = [];
  bool _isLoading = false;

  OrderProvider(this._orderService);

  List<app_models.Order> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> fetchOrders({String? customerId, String? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await _orderService.getOrders(customerId: customerId, status: status);
    } catch (e) {
      // 에러 처리
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrder(app_models.Order order) async {
    try {
      await _orderService.createOrder(order);
      await fetchOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrder(app_models.Order order) async {
    try {
      await _orderService.updateOrder(order);
      await fetchOrders();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _orderService.deleteOrder(orderId);
      await fetchOrders();
    } catch (e) {
      rethrow;
    }
  }
}

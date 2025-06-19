import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  OrderProvider(this._orderService);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrders({String? customerId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (customerId != null) {
        _orders = await _orderService.getOrdersByCustomer(customerId);
      } else {
        _orders = await _orderService.getAllOrders();
      }
      print('Loaded ${_orders.length} orders');
    } catch (e) {
      _error = e.toString();
      print('Error loading orders: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOrder(Order order) async {
    print('OrderProvider.addOrder called with order: ${order.title}');
    try {
      await _orderService.createOrder(order);
      print('OrderService.createOrder completed');
      await loadOrders(); // 목록 새로고침
      print('OrderProvider.loadOrders completed');
      print('Order added successfully');
    } catch (e) {
      _error = e.toString();
      print('Error adding order: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateOrder(Order order) async {
    try {
      await _orderService.updateOrder(order);
      await loadOrders(); // 목록 새로고침
      print('Order updated successfully');
    } catch (e) {
      _error = e.toString();
      print('Error updating order: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _orderService.deleteOrder(orderId);
      await loadOrders(); // 목록 새로고침
      print('Order deleted successfully');
    } catch (e) {
      _error = e.toString();
      print('Error deleting order: $e');
      notifyListeners();
      throw e;
    }
  }

  Future<List<Order>> getPendingOrders() async {
    try {
      return await _orderService.getPendingOrders();
    } catch (e) {
      print('Error getting pending orders: $e');
      return [];
    }
  }
} 
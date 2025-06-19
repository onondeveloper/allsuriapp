import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/firebase_service.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  OrderProvider(this._firebaseService);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrders({String? customerId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final allOrders = await _firebaseService.getOrders();
      if (customerId != null) {
        _orders = allOrders.where((order) => order.customerId == customerId).toList();
      } else {
        _orders = allOrders;
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.createOrder(order);
      await loadOrders(customerId: order.customerId);
      print('Order added successfully');
    } catch (e) {
      _error = e.toString();
      print('Error adding order: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        final updatedOrder = Order(
          id: _orders[index].id,
          customerId: _orders[index].customerId,
          title: _orders[index].title,
          description: _orders[index].description,
          address: _orders[index].address,
          visitDate: _orders[index].visitDate,
          status: status,
          createdAt: _orders[index].createdAt,
          images: _orders[index].images,
          estimatedPrice: _orders[index].estimatedPrice,
          technicianId: _orders[index].technicianId,
          selectedEstimateId: _orders[index].selectedEstimateId,
        );
        
        await _firebaseService.createOrder(updatedOrder); // This will overwrite the existing document
        _orders[index] = updatedOrder;
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating order status: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
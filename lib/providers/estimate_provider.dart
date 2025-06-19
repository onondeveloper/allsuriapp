import 'package:flutter/foundation.dart';
import '../models/estimate.dart';
import '../services/firebase_service.dart';

class EstimateProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  List<Estimate> _estimates = [];
  bool _isLoading = false;
  String? _error;

  EstimateProvider(this._firebaseService);

  List<Estimate> get estimates => _estimates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEstimates(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allEstimates = await _firebaseService.getEstimates();
      _estimates = allEstimates.where((estimate) => estimate.orderId == orderId).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading estimates: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createEstimate(Estimate estimate) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.createEstimate(estimate);
      _estimates.add(estimate);
    } catch (e) {
      _error = e.toString();
      print('Error creating estimate: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateEstimateStatus(String estimateId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _estimates.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final updatedEstimate = Estimate(
          id: _estimates[index].id,
          orderId: _estimates[index].orderId,
          technicianId: _estimates[index].technicianId,
          price: _estimates[index].price,
          description: _estimates[index].description,
          estimatedDays: _estimates[index].estimatedDays,
          status: status,
          createdAt: _estimates[index].createdAt,
        );
        
        await _firebaseService.createEstimate(updatedEstimate); // This will overwrite the existing document
        _estimates[index] = updatedEstimate;
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating estimate status: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
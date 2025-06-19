import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/dynamodb_service.dart';

class UserProvider with ChangeNotifier {
  final DynamoDBService _dbService;
  List<User> _businessUsers = [];
  bool _isLoading = false;
  String? _error;

  UserProvider(this._dbService);

  List<User> get businessUsers => _businessUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBusinessUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _dbService.getUsersByRole(UserRole.business.value);
      _businessUsers = items.map((item) => User.fromMap(item)).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading business users: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
} 
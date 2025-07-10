import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService;
  List<User> _businessUsers = [];
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserProvider(this._authService);

  List<User> get businessUsers => _businessUsers;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBusinessUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final users = await _authService.getUsers();
      _businessUsers = users
          .where((user) => user.role == UserRole.business)
          .toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading business users: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.signInWithEmailAndPassword(email, password);
      if (success) {
        _currentUser = _authService.currentUser;
      } else {
        _error = '로그인에 실패했습니다.';
      }
    } catch (e) {
      _error = e.toString();
      print('Error signing in: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(
      String email, String password, String name, UserRole role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = User(
        id: 'new_user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );
      final success = await _authService.createUserWithEmailAndPassword(email, password, user);
      if (success) {
        _currentUser = user;
      } else {
        _error = '회원가입에 실패했습니다.';
      }
    } catch (e) {
      _error = e.toString();
      print('Error signing up: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
      print('Error signing out: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> clearCurrentUser() async {
    _currentUser = null;
    notifyListeners();
  }

  // 익명 사용자 생성 (로그인하지 않은 고객용)
  Future<void> createAnonymousUser(String phoneNumber, String name) async {
    final anonymousUser = User(
      id: 'anonymous_${DateTime.now().millisecondsSinceEpoch}',
      email: null,
      name: name,
      role: UserRole.customer,
      phoneNumber: phoneNumber,
      isAnonymous: true,
      createdAt: DateTime.now(),
    );
    
    _currentUser = anonymousUser;
    notifyListeners();
  }

  // 전화번호로 익명 사용자 찾기
  User? findAnonymousUserByPhone(String phoneNumber) {
    if (_currentUser != null && 
        _currentUser!.isAnonymous == true && 
        _currentUser!.phoneNumber == phoneNumber) {
      return _currentUser;
    }
    return null;
  }

  // 사업자 상태 업데이트
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      final userIndex = _businessUsers.indexWhere((user) => user.id == userId);
      if (userIndex != -1) {
        _businessUsers[userIndex] = _businessUsers[userIndex].copyWith(status: status);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      print('Error updating user status: $e');
    }
  }

  // 사업자 삭제
  Future<void> deleteUser(String userId) async {
    try {
      _businessUsers.removeWhere((user) => user.id == userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error deleting user: $e');
    }
  }
}

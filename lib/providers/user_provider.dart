import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  AuthService? _authService;
  User? _currentUser;
  bool _isLoading = false;

  UserProvider(this._authService) {
    _authService?.addListener(_onAuthChanged);
    _currentUser = _authService?.currentUser;
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  void _onAuthChanged() {
    _currentUser = _authService?.currentUser;
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService?.signInWithEmailAndPassword(email, password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService?.signInAnonymously();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createAnonymousUser(String phoneNumber, String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 익명 사용자 생성
      await _authService?.signInAnonymously();
      
      // 사용자 정보 업데이트
      await _authService?.updateUserProfile(name: name, phoneNumber: phoneNumber);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService?.signInWithGoogle();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService?.signOut();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? name, String? phoneNumber}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService?.updateUserProfile(name: name, phoneNumber: phoneNumber);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 현재 사용자 설정
  Future<void> setCurrentUser(User user) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = user;
      // 실제로는 서버에 사용자 정보 업데이트 요청
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }
}

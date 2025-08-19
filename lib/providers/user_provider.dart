import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  AuthService? _authService;
  app_models.User? _currentUser;
  bool _isLoading = false;
  final SupabaseClient _sb = Supabase.instance.client;

  List<app_models.User> _businessUsers = [];

  UserProvider(this._authService) {
    _authService?.addListener(_onAuthChanged);
    _currentUser = _authService?.currentUser;
  }

  app_models.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  List<app_models.User> get businessUsers => _businessUsers;

  void _onAuthChanged() {
    _currentUser = _authService?.currentUser;
    notifyListeners();
  }

  // Admin: Load business users
  Future<void> loadBusinessUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await _sb
          .from('users')
          .select()
          .eq('role', 'business')
          .order('createdAt', ascending: false);
      _businessUsers = rows
          .map((r) => app_models.User.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      _businessUsers = [];
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin: Update business user status (pending/approved/rejected)
  Future<void> updateUserStatus(String userId, String status) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _sb.from('users').update({'businessStatus': status}).eq('id', userId);
      final idx = _businessUsers.indexWhere((u) => u.id == userId);
      if (idx != -1) {
        _businessUsers[idx] = _businessUsers[idx].copyWith(businessStatus: status);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin: Soft delete business user — demote to customer and mark rejected
  Future<void> deleteUser(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _sb.from('users').update({'role': 'customer', 'businessStatus': 'rejected'}).eq('id', userId);
      _businessUsers.removeWhere((u) => u.id == userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      // Supabase는 익명 로그인을 지원하지 않음 → 단순히 프로필 정보만 로컬 사용자에 반영하도록 처리
      if (_authService?.currentUser != null) {
        await _authService?.updateUserProfile(name: name, phoneNumber: phoneNumber);
      }
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
  Future<void> setCurrentUser(app_models.User user) async {
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

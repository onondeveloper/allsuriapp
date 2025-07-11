import 'package:flutter/foundation.dart';
import '../models/anonymous_user.dart';
import '../services/anonymous_service.dart';

class AnonymousProvider extends ChangeNotifier {
  final AnonymousService _anonymousService;
  
  AnonymousUser? _currentAnonymousUser;
  bool _isLoading = false;
  String? _error;

  AnonymousProvider(this._anonymousService) {
    _loadExistingUser();
  }

  AnonymousUser? get currentAnonymousUser => _currentAnonymousUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAnonymous => _currentAnonymousUser != null;

  // 기존 익명 사용자 로드
  Future<void> _loadExistingUser() async {
    await _anonymousService.loadExistingAnonymousUser();
    _currentAnonymousUser = _anonymousService.currentAnonymousUser;
    notifyListeners();
  }

  // 익명 사용자 생성 또는 가져오기
  Future<AnonymousUser> createOrGetAnonymousUser({
    String? name,
    String? phone,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _anonymousService.createOrGetAnonymousUser(
        name: name,
        phone: phone,
        email: email,
      );
      
      _currentAnonymousUser = user;
      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // 익명 사용자 정보 업데이트
  Future<void> updateAnonymousUser({
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      await _anonymousService.updateAnonymousUser(
        name: name,
        phone: phone,
        email: email,
      );
      
      _currentAnonymousUser = _anonymousService.currentAnonymousUser;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 익명 사용자 삭제 (로그인 시)
  Future<void> deleteAnonymousUser() async {
    try {
      await _anonymousService.deleteAnonymousUser();
      _currentAnonymousUser = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 익명 사용자 정보 가져오기
  Future<AnonymousUser?> getAnonymousUser(String userId) async {
    try {
      return await _anonymousService.getAnonymousUser(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 
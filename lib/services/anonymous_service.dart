// (미사용) Firebase 기반 익명 사용자 서비스 — Supabase Auth로 대체됨
import 'package:flutter/foundation.dart';
import '../models/anonymous_user.dart';

class AnonymousService extends ChangeNotifier {
  
  AnonymousUser? _currentAnonymousUser;

  // 익명 사용자 생성
  Future<String> createAnonymousUser(String phoneNumber) async {
    try {
      // Firebase 제거됨: 더미 ID 반환
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      rethrow;
    }
  }

  // 익명 사용자 인증
  Future<bool> authenticateAnonymousUser(String userId, String phoneNumber) async {
    try {
      // Firebase 제거됨: 항상 false
      return false;
    } catch (e) {
      return false;
    }
  }

  // 익명 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getAnonymousUserInfo(String userId) async {
    try {
      // Firebase 제거됨
      return null;
    } catch (e) {
      return null;
    }
  }

  // Provider에서 필요한 메서드들 추가
  AnonymousUser? get currentAnonymousUser => _currentAnonymousUser;

  Future<void> loadExistingAnonymousUser() async {
    // 기존 익명 사용자 로드 로직 - 현재는 빈 구현
    return;
  }

  Future<AnonymousUser> createOrGetAnonymousUser({
    String? name,
    String? phone,
    String? email,
  }) async {
    // 익명 사용자 생성 또는 가져오기 - 현재는 기본 구현
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentAnonymousUser = AnonymousUser(
      id: id,
      name: name,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
    );
    return _currentAnonymousUser!;
  }

  Future<void> updateAnonymousUser({
    String? name,
    String? phone,
    String? email,
  }) async {
    if (_currentAnonymousUser != null) {
      _currentAnonymousUser = _currentAnonymousUser!.copyWith(
        name: name,
        phone: phone,
        email: email,
      );
      notifyListeners();
    }
  }

  Future<void> deleteAnonymousUser() async {
    _currentAnonymousUser = null;
    notifyListeners();
  }

  Future<AnonymousUser?> getAnonymousUser(String userId) async {
    // 임시 구현
    return _currentAnonymousUser;
  }
} 
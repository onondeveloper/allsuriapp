import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_user.dart';

class AnonymousService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  AnonymousUser? _currentAnonymousUser;

  // 익명 사용자 생성
  Future<String> createAnonymousUser(String phoneNumber) async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        // 익명 사용자 정보를 Firestore에 저장
        await _firestore.collection('users').doc(user.uid).set({
          'id': user.uid,
          'phoneNumber': phoneNumber,
          'isAnonymous': true,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        return user.uid;
      }
      
      throw Exception('익명 사용자 생성 실패');
    } catch (e) {
      print('Error creating anonymous user: $e');
      rethrow;
    }
  }

  // 익명 사용자 인증
  Future<bool> authenticateAnonymousUser(String userId, String phoneNumber) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['phoneNumber'] == phoneNumber && data['isAnonymous'] == true;
      }
      return false;
    } catch (e) {
      print('Error authenticating anonymous user: $e');
      return false;
    }
  }

  // 익명 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getAnonymousUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting anonymous user info: $e');
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
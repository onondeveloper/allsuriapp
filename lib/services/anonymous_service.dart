import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnonymousService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
} 
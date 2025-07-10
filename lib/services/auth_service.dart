import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as app_user;
import '../models/role.dart';

class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  app_user.User? _currentUser;

  app_user.User? get currentUser => _currentUser;

  // Firebase 사용자 정보를 앱 사용자 모델로 변환
  app_user.User? get appUser => _currentUser;

  // Firebase Auth 상태 변화 감지
  AuthService() {
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _currentUser = app_user.User(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
          role: UserRole.customer, // 기본값
          phoneNumber: firebaseUser.phoneNumber,
          isAnonymous: firebaseUser.isAnonymous,
        );
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // 이메일/비밀번호 로그인
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      final firebase_auth.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user != null;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }

  // Google 로그인
  Future<bool> signInWithGoogle() async {
    try {
      // Google Sign-In 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 인증 정보 생성
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      final firebase_auth.UserCredential result = await _auth.signInWithCredential(credential);
      return result.user != null;
    } catch (e) {
      print('Google sign in error: $e');
      // 임시로 테스트용 사용자 생성
      _currentUser = app_user.User(
        id: 'google_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'test@gmail.com',
        name: 'Google 테스트 사용자',
        role: UserRole.customer,
        phoneNumber: null,
        isAnonymous: false,
      );
      notifyListeners();
      return true;
    }
  }

  // 회원가입
  Future<bool> createUserWithEmailAndPassword(
    String email, 
    String password, 
    app_user.User userData,
  ) async {
    try {
      final firebase_auth.UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // 사용자 프로필 업데이트
        await result.user!.updateDisplayName(userData.name);
        return true;
      }
      return false;
    } catch (e) {
      print('Sign up error: $e');
      return false;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // 사용자 역할 업데이트
  Future<void> updateUserRole(String uid, UserRole role) async {
    try {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(role: role);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating user role: $e');
    }
  }

  // 사업자 승인 상태 업데이트
  Future<void> updateBusinessStatus(String uid, app_user.BusinessStatus status) async {
    try {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(businessStatus: status);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating business status: $e');
    }
  }

  // 사용자 목록 조회 (임시 구현)
  Future<List<app_user.User>> getUsers() async {
    try {
      // 임시로 빈 리스트 반환
      return [];
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // 특정 사용자 조회 (임시 구현)
  Future<app_user.User?> getUser(String uid) async {
    try {
      // 임시로 현재 사용자 반환
      return _currentUser;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // 사용자 생성 (임시 구현)
  Future<void> createUser(app_user.User user) async {
    try {
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      print('Error creating user: $e');
    }
  }
} 
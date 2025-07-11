import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_models;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  app_models.User? _currentUser;
  bool _isLoading = false;

  app_models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      await _loadUserData(firebaseUser.uid);
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = app_models.User.fromMap(doc.data()!);
      } else {
        // 사용자 데이터가 없으면 기본 사용자 생성
        _currentUser = app_models.User(
          id: uid,
          name: '사용자',
          email: _auth.currentUser?.email ?? '',
          role: 'customer',
          phoneNumber: _auth.currentUser?.phoneNumber,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      _currentUser = null;
    }
  }

  Future<void> signInAnonymously() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        // 익명 사용자 데이터 생성
        final anonymousUser = app_models.User(
          id: user.uid,
          name: '고객',
          email: '',
          role: 'customer',
          phoneNumber: null,
          createdAt: DateTime.now(),
        );
        
        try {
          await _firestore.collection('users').doc(user.uid).set(anonymousUser.toMap());
        } catch (e) {
          print('사용자 데이터 저장 오류: $e');
          // 데이터 저장 실패해도 로그인은 성공으로 처리
        }
        _currentUser = anonymousUser;
      }
    } catch (e) {
      print('익명 로그인 오류: $e');
      // 오류를 다시 던지지 않고 사용자에게 알림
      _isLoading = false;
      notifyListeners();
      return;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Google Sign-In 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        print('Google 로그인이 취소되었습니다.');
        return;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Firebase 인증 정보 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        // 사용자 정보 확인
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          // 기존 사용자인 경우
          final userData = userDoc.data() as Map<String, dynamic>;
          _currentUser = app_models.User.fromMap(userData);
        } else {
          // 새로운 사용자인 경우 사업자로 등록
          final businessUser = app_models.User(
            id: user.uid,
            name: user.displayName ?? '사업자',
            email: user.email ?? '',
            role: 'business',
            phoneNumber: user.phoneNumber,
            createdAt: DateTime.now(),
          );
          
          try {
            await _firestore.collection('users').doc(user.uid).set(businessUser.toMap());
            _currentUser = businessUser;
          } catch (e) {
            print('사용자 데이터 저장 오류: $e');
            // 데이터 저장 실패해도 로그인은 성공으로 처리
            _currentUser = businessUser;
          }
        }
      }
    } catch (e) {
      print('Google 로그인 오류: $e');
      // 오류를 다시 던지지 않고 사용자에게 알림
      if (e.toString().contains('network_error')) {
        print('네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.');
      } else if (e.toString().contains('sign_in_canceled')) {
        print('로그인이 취소되었습니다.');
      } else {
        print('로그인 중 오류가 발생했습니다: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      
      if (user != null) {
        await _loadUserData(user.uid);
      }
    } catch (e) {
      print('이메일 로그인 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _googleSignIn.signOut();
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      print('로그아웃 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({String? name, String? phoneNumber}) async {
    if (_currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final updatedUser = app_models.User(
        id: _currentUser!.id,
        name: name ?? _currentUser!.name,
        email: _currentUser!.email,
        role: _currentUser!.role,
        phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
        createdAt: _currentUser!.createdAt,
      );
      
      await _firestore.collection('users').doc(_currentUser!.id).update(updatedUser.toMap());
      _currentUser = updatedUser;
    } catch (e) {
      print('프로필 업데이트 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 
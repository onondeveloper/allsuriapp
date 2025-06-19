// import 'package:flutter/material.dart';
// import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
// import '../services/kakao_auth_service.dart';

// class KakaoAuthProvider with ChangeNotifier {
//   User? _user;
//   bool _isLoading = false;
//   final KakaoAuthService _authService = KakaoAuthService();

//   User? get user => _user;
//   bool get isLoading => _isLoading;
//   bool get isLoggedIn => _user != null;

//   Future<bool> signIn() async {
//     try {
//       _isLoading = true;
//       notifyListeners();

//       _user = await _authService.signInWithKakao();
      
//       _isLoading = false;
//       notifyListeners();
      
//       return _user != null;
//     } catch (error) {
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<void> signOut() async {
//     try {
//       await _authService.signOut();
//       _user = null;
//       notifyListeners();
//     } catch (error) {
//       print('로그아웃 실패: $error');
//     }
//   }

//   Future<void> unlink() async {
//     try {
//       await _authService.unlink();
//       _user = null;
//       notifyListeners();
//     } catch (error) {
//       print('연결 해제 실패: $error');
//     }
//   }
// } 
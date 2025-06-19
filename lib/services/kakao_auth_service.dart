import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class KakaoAuthService {
  static final KakaoAuthService _instance = KakaoAuthService._internal();

  factory KakaoAuthService() {
    return _instance;
  }

  KakaoAuthService._internal();

  Future<User?> signInWithKakao() async {
    try {
      // 테스트용으로 바로 카카오 계정으로 로그인
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
      final user = await UserApi.instance.me();
      return user;
    } catch (error) {
      print('카카오 로그인 실패: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (error) {
      print('카카오 로그아웃 실패: $error');
    }
  }

  Future<void> unlink() async {
    try {
      await UserApi.instance.unlink();
    } catch (error) {
      print('카카오 연결 해제 실패: $error');
    }
  }
} 
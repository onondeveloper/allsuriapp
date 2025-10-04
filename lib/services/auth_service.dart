import 'package:flutter/foundation.dart';
// Supabase Auth 전환: Firebase/GoogleSignIn 제거
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'api_service.dart';
import '../supabase_config.dart';
import '../models/user.dart' as app_models;

class AuthService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  
  app_models.User? _currentUser;
  bool _isLoading = false;
  bool _needsRoleSelection = false; // 역할 선택이 필요한지 표시

  app_models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get needsRoleSelection => _needsRoleSelection; // 역할 선택 필요 여부

  AuthService() {
    _sb.auth.onAuthStateChange.listen((event) async {
      final session = event.session;
      final supaUserId = session?.user.id;
      if (supaUserId != null) {
        await _loadUserData(supaUserId);
      } else {
        _currentUser = null;
        _needsRoleSelection = false;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      print('=== _loadUserData 시작 ===');
      print('UID: $uid');
      
      final row = await _sb.from('users').select().eq('id', uid).maybeSingle();
      print('데이터베이스 결과: $row');
      
      // Google 메타데이터 동기화 (full_name)
      final supaUser = _sb.auth.currentUser;
      final Map<String, dynamic>? meta = (supaUser?.userMetadata is Map<String, dynamic>)
          ? (supaUser!.userMetadata as Map<String, dynamic>)
          : null;
      final String? fullName = meta != null ? (meta['full_name'] as String?) : null;
      print('Google 메타데이터 full_name: $fullName');
      
      if (row != null) {
        // 필요 시 이름 갱신
        if (fullName != null && fullName.isNotEmpty && row['name'] != fullName) {
          await _sb.from('users').update({'name': fullName}).eq('id', uid);
          row['name'] = fullName;
        }
        
        // 사용자 역할이 설정되어 있는지 확인
        final userRole = row['role'] as String?;
        print('데이터베이스에서 읽은 역할: $userRole');
        
        if (userRole != null && userRole.isNotEmpty && userRole != 'customer') {
          _currentUser = app_models.User.fromMap(Map<String, dynamic>.from(row));
          _needsRoleSelection = false;
          print('사용자 역할 로드됨: $userRole, _needsRoleSelection: $_needsRoleSelection');
        } else {
          // 역할이 설정되지 않았거나 customer인 경우 역할 선택 필요
          final updatedUser = app_models.User.fromMap(Map<String, dynamic>.from(row));
          _currentUser = updatedUser;
          _needsRoleSelection = true;
          print('역할 선택이 필요합니다. 현재 역할: ${userRole ?? "설정되지 않음"}, _needsRoleSelection: $_needsRoleSelection');
        }
        return;
      }
      
      // 새 사용자인 경우 기본 역할 설정
      final fallbackUser = app_models.User(
        id: uid,
        name: fullName ?? '사용자',
        email: _sb.auth.currentUser?.email ?? '',
        role: 'customer', // 기본 역할을 customer로 설정
        phoneNumber: null,
        createdAt: DateTime.now(),
      );
      await _sb.from('users').insert(fallbackUser.toMap());
      _currentUser = fallbackUser;
      _needsRoleSelection = true; // 새 사용자는 역할 선택 필요
      print('새 사용자 생성됨, 기본 역할: customer, _needsRoleSelection: $_needsRoleSelection');
    } catch (e) {
      print('사용자 데이터 로드/생성 오류: $e');
      _currentUser = null;
      _needsRoleSelection = false;
    }
  }

  Future<void> signInAnonymously() async {
    // Supabase Auth는 익명 로그인을 지원하지 않습니다.
    throw UnsupportedError('Anonymous sign-in is not supported with Supabase Auth.');
  }

  Future<void> signInWithGoogle({String? redirectUrl}) async {
    throw UnsupportedError('Google sign-in is disabled. Use signInWithKakao instead.');
  }

  Future<bool> signInWithKakao() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Ensure Kakao SDK is initialized even if app was launched without dart-define
      final nativeAppKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
      if (nativeAppKey.isNotEmpty) {
        try { kakao.KakaoSdk.init(nativeAppKey: nativeAppKey); } catch (_) {}
      } else {
        // If no key provided and test bypass is enabled, go straight to bypass
        if (const bool.fromEnvironment('ALLOW_TEST_KAKAO', defaultValue: false)) {
          final api = ApiService();
          final resp = await api.post('/auth/kakao/login', { 'access_token': 'TEST_BYPASS' });
          if (resp['success'] == true) {
            final data = resp['data'] as Map<String, dynamic>;
            final backendToken = data['token'] as String?;
            if (backendToken != null && backendToken.isNotEmpty) {
              ApiService.setBearerToken(backendToken);
              final user = data['user'] as Map<String, dynamic>?;
              if (user != null) {
                final uid = user['id'] as String;
                // 1) 먼저 로컬 사용자 세팅(즉시 화면 전환 보장)
                _currentUser = app_models.User(
                  id: uid,
                  name: (user['name']?.toString() ?? '사용자'),
                  email: (user['email']?.toString() ?? ''),
                  role: (user['role']?.toString() ?? 'customer'),
                  phoneNumber: null,
                  createdAt: DateTime.now(),
                );
                _needsRoleSelection = true;
                notifyListeners();
                // 2) Supabase가 설정되어 있으면 추가 로드(실패해도 무시)
                if (SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty) {
                  try { await _loadUserData(uid); } catch (_) {}
                }
              }
              return true;
            }
          }
        }
        // No key and no bypass: fail gracefully
        print('Kakao SDK key missing. Provide KAKAO_NATIVE_APP_KEY via --dart-define.');
        return false;
      }

      // Kakao 로그인 (톡 우선). 실패 시 계정 로그인으로 폴백
      kakao.OAuthToken token;
      try {
        if (await kakao.isKakaoTalkInstalled()) {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } else {
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } catch (_) {
        // 앱 미설치/취소 등 케이스에서 계정 로그인 재시도
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 백엔드로 토큰 교환
      final api = ApiService();
      final resp = await api.post('/auth/kakao/login', {
        'access_token': token.accessToken,
      });
      if (resp['success'] == true) {
        final data = resp['data'] as Map<String, dynamic>;
        final backendToken = data['token'] as String?;
        if (backendToken != null && backendToken.isNotEmpty) {
          ApiService.setBearerToken(backendToken);
          // 백엔드가 user를 반환하므로 메모리에 반영 (필요 시 Supabase users 테이블과 동기화)
          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            final uid = user['id'] as String;
            // 1) 먼저 로컬 사용자 세팅(즉시 화면 전환 보장)
            _currentUser = app_models.User(
              id: uid,
              name: (user['name']?.toString() ?? '사용자'),
              email: (user['email']?.toString() ?? ''),
              role: (user['role']?.toString() ?? 'customer'),
              phoneNumber: null,
              createdAt: DateTime.now(),
            );
            _needsRoleSelection = true;
            notifyListeners();
            // 2) Supabase가 설정되어 있으면 추가 로드(실패해도 무시)
            if (SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty) {
              try { await _loadUserData(uid); } catch (_) {}
            }
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Kakao 로그인 오류: $e');
      // 에뮬레이터/테스트 장비 우회를 위한 개발용 백도어 (서버에서 ALLOW_TEST_KAKAO=true 설정 필요)
      if (const bool.fromEnvironment('ALLOW_TEST_KAKAO', defaultValue: false)) {
        try {
          final api = ApiService();
          final resp = await api.post('/auth/kakao/login', {
            'access_token': 'TEST_BYPASS',
          });
          if (resp['success'] == true) {
            final data = resp['data'] as Map<String, dynamic>;
            final backendToken = data['token'] as String?;
            if (backendToken != null && backendToken.isNotEmpty) {
              ApiService.setBearerToken(backendToken);
              final user = data['user'] as Map<String, dynamic>?;
              if (user != null) {
                final uid = user['id'] as String;
                await _loadUserData(uid);
              }
              return true;
            }
          }
        } catch (_) {}
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      final res = await _sb.auth.signInWithPassword(email: email, password: password);
      final userId = res.user?.id;
      if (userId != null) {
        await _loadUserData(userId);
      }
    } catch (e) {
      print('이메일 로그인 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, {String name = '사용자'}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final res = await _sb.auth.signUp(email: email, password: password);
      final userId = res.user?.id;
      if (userId != null) {
        final profile = app_models.User(
          id: userId,
          email: email,
          name: name,
          role: 'customer',
          phoneNumber: null,
          createdAt: DateTime.now(),
        );
        await _sb.from('users').upsert(profile.toMap());
        _currentUser = profile;
      }
    } catch (e) {
      print('회원가입 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _sb.auth.signOut();
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
      
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
      if (updates.isNotEmpty) {
        await _sb.from('users').update(updates).eq('id', _currentUser!.id);
        _currentUser = _currentUser!.copyWith(
          name: name,
          phoneNumber: phoneNumber,
        );
      }
    } catch (e) {
      print('프로필 업데이트 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRole(String role) async {
    if (_currentUser == null) return;
    try {
      _isLoading = true;
      notifyListeners();
      final update = {
        'role': role,
        if (role == 'business') 'businessStatus': 'pending',
      };
      final supaReady = SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty;
      if (supaReady) {
        await _sb.from('users').update(update).eq('id', _currentUser!.id);
      }
      // Always update local state so UI can transition immediately
      _currentUser = _currentUser!.copyWith(
        role: role,
        businessStatus: role == 'business' ? 'pending' : _currentUser!.businessStatus,
      );
      _needsRoleSelection = false; // 역할 선택 완료
      print('사용자 역할이 업데이트되었습니다(로컬 적용${supaReady ? '' : ' - Supabase 미설정'}): $role');
    } catch (e) {
      // 비정상 상황에서도 로컬 업데이트를 반영하여 화면 전환 보장
      _currentUser = _currentUser!.copyWith(
        role: role,
        businessStatus: role == 'business' ? 'pending' : _currentUser!.businessStatus,
      );
      _needsRoleSelection = false;
      print('역할 업데이트 오류(로컬로 계속): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBusinessProfile({
    String? name,
    String? phoneNumber,
    required String businessName,
    String? businessNumber,
    String? address,
    List<String>? serviceAreas,
    List<String>? specialties,
  }) async {
    if (_currentUser == null) return;
    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'businessName': businessName,
        if (businessNumber != null) 'businessNumber': businessNumber,
        if (address != null) 'address': address,
        if (serviceAreas != null) 'serviceAreas': serviceAreas,
        if (specialties != null) 'specialties': specialties,
        'role': 'business',
        'businessStatus': _currentUser!.businessStatus ?? 'pending',
      };
      await _sb.from('users').update(updates).eq('id', _currentUser!.id);

      _currentUser = _currentUser!.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        role: 'business',
        businessName: businessName,
        businessNumber: businessNumber,
        address: address,
        serviceAreas: serviceAreas,
        specialties: specialties,
        businessStatus: _currentUser!.businessStatus ?? 'pending',
      );
      _needsRoleSelection = false; // 사업자 프로필 설정이 완료되었으므로 플래그 초기화
      print('사업자 프로필이 업데이트되었습니다');
    } catch (e) {
      print('사업자 프로필 업데이트 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 
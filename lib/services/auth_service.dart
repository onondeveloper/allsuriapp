import 'package:flutter/foundation.dart';
// Supabase Auth 전환: Firebase/GoogleSignIn 제거
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'api_service.dart';
import 'fcm_service.dart';
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
        print('🔍 DB에서 가져온 사업자 정보:');
        print('   - businessstatus: ${row['businessstatus']}');
        print('   - businessname: ${row['businessname']}');
        print('   - businessnumber: ${row['businessnumber']}');
        
        if (userRole != null && userRole.isNotEmpty && userRole != 'customer') {
          _currentUser = app_models.User.fromMap(Map<String, dynamic>.from(row));
          _needsRoleSelection = false;
          print('사용자 역할 로드됨: $userRole, _needsRoleSelection: $_needsRoleSelection');
          print('🔍 User 객체 생성 후:');
          print('   - businessStatus: ${_currentUser?.businessStatus}');
          print('   - businessName: ${_currentUser?.businessName}');
          print('   - businessNumber: ${_currentUser?.businessNumber}');
        } else {
          // 역할이 설정되지 않았거나 customer인 경우 역할 선택 필요
          final updatedUser = app_models.User.fromMap(Map<String, dynamic>.from(row));
          _currentUser = updatedUser;
          _needsRoleSelection = true;
          print('역할 선택이 필요합니다. 현재 역할: ${userRole ?? "설정되지 않음"}, _needsRoleSelection: $_needsRoleSelection');
        }
        
        // FCM 토큰 저장 (실패해도 로그인은 성공)
        try {
          await FCMService().saveFCMToken(uid);
        } catch (e) {
          print('⚠️ FCM 토큰 저장 실패 (무시됨): $e');
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
      
      // FCM 토큰 저장 (실패해도 로그인은 성공)
      try {
        await FCMService().saveFCMToken(uid);
      } catch (e) {
        print('⚠️ FCM 토큰 저장 실패 (무시됨): $e');
      }
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
      // Kakao SDK는 main.dart에서 이미 초기화됨 - 여기서는 초기화 생략으로 속도 향상
      final nativeAppKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
      if (nativeAppKey.isEmpty) {
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
                await _loadUserData(uid);
              }
              return true;
            }
          }
        }
        return false;
      }

      // Kakao 로그인 (톡 우선, 실패 시 계정)
      kakao.OAuthToken token;
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 백엔드로 토큰 교환 (타임아웃 설정)
      final api = ApiService();
      print('🔍 [signInWithKakao] 백엔드로 카카오 토큰 전송 중...');
      final resp = await api.post('/auth/kakao/login', {
        'access_token': token.accessToken,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => {'success': false, 'error': 'timeout'},
      );
      
      print('🔍 [signInWithKakao] 백엔드 응답: $resp');
      print('🔍 [signInWithKakao] resp[\'success\']: ${resp['success']}');
      
      if (resp['success'] == true) {
        // ApiService.post()가 응답을 한 번 감싸므로, resp['data']가 실제 백엔드 응답
        final backendResponse = resp['data'] as Map<String, dynamic>;
        print('🔍 [signInWithKakao] backendResponse: $backendResponse');
        
        // 백엔드 응답에서 실제 데이터 추출
        final actualData = backendResponse['data'] as Map<String, dynamic>?;
        print('🔍 [signInWithKakao] actualData: $actualData');
        
        if (actualData != null) {
          final backendToken = actualData['token'] as String?;
          print('🔍 [signInWithKakao] token: ${backendToken != null ? "존재" : "null"}');
          
          if (backendToken != null && backendToken.isNotEmpty) {
            ApiService.setBearerToken(backendToken);
            
            final user = actualData['user'] as Map<String, dynamic>?;
            print('🔍 [signInWithKakao] user: $user');
            
            if (user != null) {
              final uid = user['id'] as String;
              
              // Supabase JWT 토큰 설정 (백엔드에서 발급한 토큰)
              final supabaseAccessToken = actualData['supabase_access_token'] as String?;
              if (supabaseAccessToken != null && supabaseAccessToken.isNotEmpty) {
                print('🔍 [signInWithKakao] Supabase JWT 토큰 설정 중...');
                try {
                  // Supabase 세션 설정
                  await _sb.auth.setSession(supabaseAccessToken);
                  print('✅ [signInWithKakao] Supabase 세션 설정 완료');
                  print('   - Current User: ${_sb.auth.currentUser?.id}');
                } catch (e) {
                  print('❌ [signInWithKakao] Supabase 세션 설정 실패: $e');
                }
              }
              
              // Supabase에서 전체 사용자 정보 로드 (사업자 정보 포함)
              print('🔍 [signInWithKakao] 백엔드 응답 받음, Supabase에서 전체 정보 로드 시작');
              print('   - UID: $uid');
              await _loadUserData(uid);
              print('🔍 [signInWithKakao] Supabase 로드 완료');
              print('   - Business Status: ${_currentUser?.businessStatus}');
              print('   - Business Name: ${_currentUser?.businessName}');
            }
            return true;
          }
        }
      } else if (const bool.fromEnvironment('ALLOW_TEST_KAKAO', defaultValue: false)) {
        // 서버 검증 실패 시 테스트 바이패스 세컨드 찬스
        final retry = await api.post('/auth/kakao/login', { 'access_token': 'TEST_BYPASS' });
        if (retry['success'] == true) {
          final data = retry['data'] as Map<String, dynamic>;
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
      
      // FCM 토큰 삭제 (실패해도 로그아웃은 계속)
      if (_currentUser != null) {
        try {
          await FCMService().deleteFCMToken(_currentUser!.id);
        } catch (e) {
          print('⚠️ FCM 토큰 삭제 실패 (무시됨): $e');
        }
      }
      
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
      
      // 현재 businessstatus 확인
      final currentBusinessStatus = _currentUser!.businessStatus;
      final shouldUpdateBusinessStatus = role == 'business' && 
          (currentBusinessStatus == null || currentBusinessStatus.isEmpty);
      
      // Supabase 테이블 컬럼명에 맞춤 (소문자)
      final update = {
        'role': role,
        // ⚠️ 이미 승인된 사용자의 businessstatus를 덮어쓰지 않도록 수정
        // businessstatus가 없거나 비어있을 때만 'pending'으로 설정
        if (shouldUpdateBusinessStatus) 'businessstatus': 'pending',
      };
      
      final supaReady = SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty;
      if (supaReady) {
        final result = await _sb.from('users').update(update).eq('id', _currentUser!.id).select();
        print('✅ Supabase 역할 업데이트 성공: ${_currentUser!.id}, role=$role');
        print('   - 기존 businessstatus: $currentBusinessStatus');
        print('   - businessstatus 업데이트 여부: $shouldUpdateBusinessStatus');
        print('   - 업데이트된 데이터: $result');
      }
      
      // Always update local state so UI can transition immediately
      // businessstatus는 기존 값을 유지 (새로 설정하는 경우만 pending)
      _currentUser = _currentUser!.copyWith(
        role: role,
        businessStatus: shouldUpdateBusinessStatus ? 'pending' : currentBusinessStatus,
      );
      _needsRoleSelection = false; // 역할 선택 완료
      print('사용자 역할이 업데이트되었습니다(로컬 적용${supaReady ? '' : ' - Supabase 미설정'}): $role');
      print('   - 최종 businessStatus: ${_currentUser!.businessStatus}');
    } catch (e) {
      // 비정상 상황에서도 로컬 업데이트를 반영하여 화면 전환 보장
      final currentBusinessStatus = _currentUser!.businessStatus;
      final shouldUpdateBusinessStatus = role == 'business' && 
          (currentBusinessStatus == null || currentBusinessStatus.isEmpty);
      
      _currentUser = _currentUser!.copyWith(
        role: role,
        businessStatus: shouldUpdateBusinessStatus ? 'pending' : currentBusinessStatus,
      );
      _needsRoleSelection = false;
      print('❌ 역할 업데이트 오류(로컬로 계속): $e');
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

      // Supabase 테이블 컬럼명에 맞춤 (소문자)
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phonenumber': phoneNumber,  // 소문자
        'businessname': businessName,  // 소문자
        if (businessNumber != null) 'businessnumber': businessNumber,  // 소문자
        if (address != null) 'address': address,
        if (serviceAreas != null) 'serviceareas': serviceAreas,  // 소문자
        if (specialties != null) 'specialties': specialties,
        'role': 'business',
        'businessstatus': _currentUser!.businessStatus ?? 'pending',  // 소문자
      };
      
      // Only sync to Supabase if project is configured and user id looks like UUID
      final supaReady = SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty;
      final uuidLike = RegExp(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}").hasMatch(_currentUser!.id);
      
      print('📝 사업자 프로필 업데이트 시도: ID=${_currentUser!.id}');
      print('   업데이트 데이터: $updates');
      
      if (supaReady && uuidLike) {
        try {
          final result = await _sb.from('users').update(updates).eq('id', _currentUser!.id).select();
          print('✅ Supabase 사업자 프로필 업데이트 성공: ${_currentUser!.id}');
          print('   업데이트된 행 수: ${result.length}');
          if (result.isNotEmpty) {
            print('   업데이트된 데이터: ${result.first}');
          } else {
            print('⚠️  경고: 업데이트는 성공했으나 반환된 데이터 없음 (해당 ID를 찾지 못했을 수 있음)');
          }
        } catch (e) {
          // Log and continue with local update so UI doesn't break
          print('❌ Supabase 동기화 실패(무시하고 로컬 반영): $e');
        }
      } else {
        print('⚠️  Supabase 업데이트 건너뜀 (supaReady: $supaReady, uuidLike: $uuidLike)');
        print('   현재 사용자 ID: ${_currentUser!.id}');
      }

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
      // 변환/검증 예외는 상위에서 안내 메시지로 처리될 수 있도록 메시지만 남김
      print('사업자 프로필 업데이트 오류(로컬 유지): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 
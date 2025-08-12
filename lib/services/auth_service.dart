import 'package:flutter/foundation.dart';
// Supabase Auth 전환: Firebase/GoogleSignIn 제거
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;

class AuthService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  
  app_models.User? _currentUser;
  bool _isLoading = false;

  app_models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    _sb.auth.onAuthStateChange.listen((event) async {
      final session = event.session;
      final supaUserId = session?.user.id;
      if (supaUserId != null) {
        await _loadUserData(supaUserId);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final row = await _sb.from('users').select().eq('id', uid).maybeSingle();
      if (row != null) {
        _currentUser = app_models.User.fromMap(Map<String, dynamic>.from(row));
        return;
      }
      final fallbackUser = app_models.User(
        id: uid,
        name: '사용자',
        email: _sb.auth.currentUser?.email ?? '',
        role: '',
        phoneNumber: null,
        createdAt: DateTime.now(),
      );
      await _sb.from('users').insert(fallbackUser.toMap());
      _currentUser = fallbackUser;
    } catch (e) {
      print('사용자 데이터 로드/생성 오류: $e');
      _currentUser = null;
    }
  }

  Future<void> signInAnonymously() async {
    // Supabase Auth는 익명 로그인을 지원하지 않습니다.
    throw UnsupportedError('Anonymous sign-in is not supported with Supabase Auth.');
  }

  Future<void> signInWithGoogle({String? redirectUrl}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl, // ex) 'io.supabase.flutter://login-callback/'
        queryParams: const {
          'prompt': 'consent select_account',
          'access_type': 'offline',
        },
      );
      // 이후 onAuthStateChange로 사용자 로드
    } catch (e) {
      print('Google OAuth 로그인 오류: $e');
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
      await _sb.from('users').update(update).eq('id', _currentUser!.id);
      _currentUser = _currentUser!.copyWith(
        role: role,
        businessStatus: role == 'business' ? 'pending' : _currentUser!.businessStatus,
      );
    } catch (e) {
      print('역할 업데이트 오류: $e');
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
    } catch (e) {
      print('사업자 프로필 업데이트 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 
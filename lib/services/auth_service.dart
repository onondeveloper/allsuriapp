import 'package:flutter/foundation.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:shared_aws_api/shared.dart' show AwsClientCredentials;
import '../config/aws_config.dart';

class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _error;
  String? _userId;
  AwsClientCredentials? _credentials;

  final userPool = CognitoUserPool(
    AwsConfig.userPoolId,
    AwsConfig.clientId,
  );

  bool get isLoggedIn => _isLoggedIn;
  String? get error => _error;
  String? get userId => _userId;
  AwsClientCredentials? get credentials => _credentials;

  AuthService() {
    // 초기화 시 자동 로그인 시도
    _initializeAuth();
    _credentials = AwsClientCredentials(
      accessKey: 'AKIAZQ3DPIQAUOT4ZNMV',
      secretKey: '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',
    );
  }

  Future<void> _initializeAuth() async {
    try {
      final currentUser = await userPool.getCurrentUser();
      if (currentUser == null) {
        _isLoggedIn = false;
        return;
      }

      final session = await currentUser.getSession();
      if (session?.isValid() ?? false) {
        _isLoggedIn = true;
        _userId = currentUser.username;
        final idToken = session?.getIdToken().getJwtToken();
        if (idToken != null) {
          await _initializeCredentials(idToken);
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      print('Error initializing auth: $e');
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<void> _initializeCredentials(String idToken) async {
    try {
      final cognitoCredentials = CognitoCredentials(
        AwsConfig.identityPoolId,
        userPool,
      );
      await cognitoCredentials.getAwsCredentials(idToken);
      _credentials = AwsClientCredentials(
        accessKey: cognitoCredentials.accessKeyId ?? '',
        secretKey: cognitoCredentials.secretAccessKey ?? '',
      );
    } catch (e) {
      print('Error initializing credentials: $e');
      _error = e.toString();
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final cognitoUser = CognitoUser(email, userPool);
      final authDetails = AuthenticationDetails(
        username: email,
        password: password,
      );

      final session = await cognitoUser.authenticateUser(authDetails);
      if (session != null) {
        _isLoggedIn = true;
        _userId = cognitoUser.username;
        _error = null;
        final idToken = session.getIdToken().getJwtToken();
        if (idToken != null) {
          await _initializeCredentials(idToken);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final currentUser = await userPool.getCurrentUser();
      if (currentUser != null) {
        await currentUser.signOut();
      }
      _isLoggedIn = false;
      _userId = null;
      _credentials = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 테스트용 임시 로그인 (실제 환경에서는 제거)
  Future<bool> signInTest() async {
    try {
      // 테스트용 AWS 인증 정보 직접 설정
      _credentials = AwsClientCredentials(
        accessKey: 'AKIAZQ3DPIQAUOT4ZNMV',  // 실제 액세스 키로 교체 필요
        secretKey: 'WMvFcjIcHVxSk93cgOHbTwjOEdkK9zzzejExsWsg',   // 실제 시크릿 키로 교체 필요
      );

      if (_credentials == null) {
        throw Exception('Failed to set AWS credentials');
      }

      _isLoggedIn = true;
      _userId = 'test_user';
      _error = null;
      
      print('AWS Credentials initialized successfully');
      print('Access Key: ${_credentials?.accessKey}');
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error in signInTest: $e');
      _error = e.toString();
      _isLoggedIn = false;
      _credentials = null;
      notifyListeners();
      return false;
    }
  }

  void updateCredentials(AwsClientCredentials credentials) {
    _credentials = credentials;
    notifyListeners();
  }
} 
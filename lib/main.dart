import 'package:flutter/material.dart';
// import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
// import 'providers/kakao_auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'providers/order_provider.dart';
import 'services/dynamodb_service.dart';
import 'services/order_service.dart';
import 'services/auth_service.dart';
// import 'services/auth_service.dart'; // 인증 기능을 사용하지 않으므로 주석 처리
import 'screens/home/home_screen.dart';
import 'providers/user_provider.dart';
import './providers/estimate_provider.dart';
import 'models/role.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  // Reset mock DB on app start
  DynamoDBService().resetMockEstimates();
  // KakaoSdk.init(
  //   nativeAppKey: '9462c73fdeaba67181aadcc46af6d293', // 여기에 카카오 네이티브 앱 키를 입력하세요
  // );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService는 더 이상 필요하지 않으므로 제거합니다.
        // Provider<AuthService>(
        //   create: (_) => AuthService(),
        // ),
        Provider<DynamoDBService>(
          create: (_) => DynamoDBService(), // AuthService 의존성 제거
        ),
        Provider<OrderService>(
          create: (_) => OrderService(AuthService()), // dummy AuthService 사용
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (context) => OrderProvider(context.read<OrderService>()),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(context.read<DynamoDBService>()),
        ),
        ChangeNotifierProvider<EstimateProvider>(
          create: (context) => EstimateProvider(context.read<DynamoDBService>()),
        ),
      ],
      child: MaterialApp(
        title: '올수리',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        home: const RoleSelectionScreen(), // 시작 화면을 RoleSelectionScreen으로 변경
        routes: {
          '/home': (context) => HomeScreen(userRole: UserRole.customer), // 기본값으로 customer 설정
          '/login': (context) => const LoginScreen(),
        },
      ),
    );
  }
}

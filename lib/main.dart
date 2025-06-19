import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'providers/order_provider.dart';
import 'services/firebase_service.dart';
import 'services/order_service.dart';
import 'services/auth_service.dart';
import 'screens/home/home_screen.dart';
import 'providers/user_provider.dart';
import './providers/estimate_provider.dart';
import 'models/role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    Provider.debugCheckInvalidValueType = null;

    runApp(const MyApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
    // You might want to show an error screen here
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app. Please try again.'),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(
          create: (_) => FirebaseService(),
        ),
        Provider<OrderService>(
          create: (_) => OrderService(AuthService()),
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (context) => OrderProvider(context.read<OrderService>()),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(context.read<FirebaseService>()),
        ),
        ChangeNotifierProvider<EstimateProvider>(
          create: (context) => EstimateProvider(context.read<FirebaseService>()),
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
          '/home': (context) => const HomeScreen(userRole: UserRole.customer), // 기본값으로 customer 설정
          '/login': (context) => const LoginScreen(),
        },
      ),
    );
  }
}

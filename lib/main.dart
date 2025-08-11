import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/estimate_service.dart';
import 'providers/user_provider.dart';
import 'providers/order_provider.dart';
import 'screens/home/home_screen.dart';
import 'widgets/business_dashboard.dart';
import 'widgets/customer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService를 먼저 생성
        ChangeNotifierProvider(create: (context) => AuthService()),
        // 다른 서비스들을 생성
        ChangeNotifierProvider(create: (context) => OrderService()),
        ChangeNotifierProvider(create: (context) => EstimateService()),
        // UserProvider는 AuthService에 의존하므로 마지막에 생성
        ChangeNotifierProxyProvider<AuthService, UserProvider>(
          create: (context) => UserProvider(Provider.of<AuthService>(context, listen: false)),
          update: (context, authService, previous) => UserProvider(authService),
        ),
      ],
      child: MaterialApp(
        title: 'Allsuri',
        theme: ThemeData(
          // Material Design 3 색상 스킴 적용
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4), // Material You purple
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // Open Sans 폰트 적용
          textTheme: GoogleFonts.openSansTextTheme(
            Theme.of(context).textTheme,
          ).apply(
            decorationColor: Colors.transparent,
          ).copyWith(
            // 모든 텍스트 스타일에서 밑줄 제거
            displayLarge: GoogleFonts.openSans(decoration: TextDecoration.none),
            displayMedium: GoogleFonts.openSans(decoration: TextDecoration.none),
            displaySmall: GoogleFonts.openSans(decoration: TextDecoration.none),
            headlineLarge: GoogleFonts.openSans(decoration: TextDecoration.none),
            headlineMedium: GoogleFonts.openSans(decoration: TextDecoration.none),
            headlineSmall: GoogleFonts.openSans(decoration: TextDecoration.none),
            titleLarge: GoogleFonts.openSans(decoration: TextDecoration.none),
            titleMedium: GoogleFonts.openSans(decoration: TextDecoration.none),
            titleSmall: GoogleFonts.openSans(decoration: TextDecoration.none),
            bodyLarge: GoogleFonts.openSans(decoration: TextDecoration.none),
            bodyMedium: GoogleFonts.openSans(decoration: TextDecoration.none),
            bodySmall: GoogleFonts.openSans(decoration: TextDecoration.none),
            labelLarge: GoogleFonts.openSans(decoration: TextDecoration.none),
            labelMedium: GoogleFonts.openSans(decoration: TextDecoration.none),
            labelSmall: GoogleFonts.openSans(decoration: TextDecoration.none),
          ),
          // 텍스트 밑줄 제거
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.transparent,
            selectionHandleColor: Colors.transparent,
          ),
          // Material Design 3 컴포넌트 스타일
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        // 디버그 배너 제거
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 항상 HomeScreen을 보여주고, 사용자가 역할을 선택할 수 있도록 함
        return const HomeScreen();
      },
    );
  }
}

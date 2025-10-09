import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/estimate_service.dart';
import 'services/job_service.dart';
import 'services/payment_service.dart';
import 'services/api_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/community_service.dart';
import 'providers/user_provider.dart';
import 'providers/order_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'widgets/business_dashboard.dart';
import 'widgets/customer_dashboard.dart';
import 'utils/navigation_utils.dart';
//126e5d87-94e0-4ad2-94ba-51b9c2454a4a
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    // 무시 가능한 외부 딥링크 예외(Supabase OAuth 등)를 앱 크래시 없이 로그만 남김
    debugPrint('FlutterError: \\n${details.exceptionAsString()}');
  };
  // Kakao SDK 초기화 (dart-define)
  final kakaoKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
  if (kakaoKey.isNotEmpty) {
    kakao.KakaoSdk.init(nativeAppKey: kakaoKey);
  }
  // Supabase 초기화 (Auth 포함)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // NotificationService 초기화
  await NotificationService().initialize();
  
  await runZonedGuarded(() async {
    runApp(const MyApp());
  }, (error, stack) {
    // 백그라운드 비동기 예외로 앱이 중단되지 않도록 보호
    debugPrint('Top-level error caught: $error');
  });
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
        ChangeNotifierProvider(create: (context) => ApiService()),
        ChangeNotifierProvider(create: (context) => OrderService()),
        ChangeNotifierProvider(create: (context) => EstimateService()),
        ChangeNotifierProvider(create: (context) => JobService()),
        ChangeNotifierProvider(create: (context) => PaymentService()),
        ChangeNotifierProvider(create: (context) => ChatService()),
        ChangeNotifierProvider(create: (context) => CommunityService()),
        // UserProvider는 AuthService에 의존하므로 마지막에 생성
        ChangeNotifierProxyProvider<AuthService, UserProvider>(
          create: (context) => UserProvider(Provider.of<AuthService>(context, listen: false)),
          update: (context, authService, previous) => UserProvider(authService),
        ),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          // Modern Google-inspired color scheme
          const seed = Color(0xFF1A73E8); // Google Blue
          final ColorScheme lightScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
            primary: const Color(0xFF1A73E8),
            secondary: const Color(0xFF34A853),
            error: const Color(0xFFEA4335),
            surface: Colors.white,
            background: const Color(0xFFF8F9FA),
          );
          final ColorScheme darkScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
            primary: const Color(0xFF4285F4),
            secondary: const Color(0xFF34A853),
            error: const Color(0xFFEA4335),
          );

          ThemeData buildTheme(ColorScheme colorScheme) {
            return ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
              textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
                displayLarge: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                displayMedium: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                displaySmall: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                headlineLarge: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                headlineMedium: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                headlineSmall: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                titleLarge: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                titleMedium: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                titleSmall: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                bodyLarge: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                bodyMedium: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                bodySmall: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                labelLarge: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                labelMedium: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
                labelSmall: GoogleFonts.notoSansKr(decoration: TextDecoration.none),
              ),
              appBarTheme: AppBarTheme(
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 2,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
                shadowColor: Colors.black.withOpacity(0.1),
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              navigationBarTheme: NavigationBarThemeData(
                elevation: 3,
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                backgroundColor: colorScheme.surface,
                indicatorColor: colorScheme.primaryContainer,
                shadowColor: Colors.black.withOpacity(0.1),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  side: BorderSide(color: colorScheme.outline, width: 1.5),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              chipTheme: ChipThemeData(
                elevation: 0,
                pressElevation: 1,
                backgroundColor: colorScheme.surfaceVariant,
                selectedColor: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              dialogTheme: DialogThemeData(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              bottomSheetTheme: BottomSheetThemeData(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.error,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.error,
                    width: 2.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                labelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              dividerTheme: DividerThemeData(
                color: colorScheme.outlineVariant,
                thickness: 1,
                space: 1,
              ),
              listTileTheme: ListTileThemeData(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

           return MaterialApp(
            title: 'Allsuri',
             theme: buildTheme(lightScheme.copyWith(
               surface: Colors.white,
               background: Colors.white,
             )),
             darkTheme: buildTheme(darkScheme.copyWith(
               surface: Colors.white,
               background: Colors.white,
             )),
             themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
             home: const HomeScreen(),
          );
        },
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
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }
        final user = authService.currentUser;
        final role = user?.role.trim() ?? '';
        final isKnownRole = role == 'admin' || role == 'business' || role == 'customer';
        if (!isKnownRole) {
          return const RoleSelectionScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

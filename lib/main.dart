import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'supabase_config.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/estimate_service.dart';
import 'services/job_service.dart';
import 'services/payment_service.dart';
import 'services/api_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';
import 'services/community_service.dart';
import 'services/fcm_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'providers/order_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/business/order_marketplace_screen.dart';
import 'widgets/professional_dashboard.dart';
import 'widgets/customer_dashboard.dart';
import 'utils/navigation_utils.dart';

// 전역 네비게이터 키 (딥링크 처리용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//126e5d87-94e0-4ad2-94ba-51b9c2454a4a
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    // 무시 가능한 외부 딥링크 예외(Supabase OAuth 등)를 앱 크래시 없이 로그만 남김
    debugPrint('FlutterError: \\n${details.exceptionAsString()}');
  };
  // Kakao SDK 초기화 (dart-define)
  final kakaoKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
  print('🔍 [Main] KAKAO_NATIVE_APP_KEY: ${kakaoKey.isNotEmpty ? "로드됨(***)" : "❌ 비어있음"}');
  
  if (kakaoKey.isNotEmpty) {
    kakao.KakaoSdk.init(nativeAppKey: kakaoKey);
    print('✅ [Main] Kakao SDK 초기화 완료');
  } else {
    print('⚠️ [Main] Kakao SDK 키가 없어 초기화를 건너뜁니다.');
  }
  // Supabase 초기화 (Auth 포함)
  print('🔍 Supabase URL: ${SupabaseConfig.url}');
  print('🔍 Supabase Key: ${SupabaseConfig.anonKey.isNotEmpty ? "✅ 로드됨" : "❌ 비어있음"}');
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // NotificationService 초기화
  await NotificationService().initialize();
  
  // LocalNotificationService 초기화
  await LocalNotificationService().initialize(
    onSelectNotification: (String? payload) {
      print('🔔 [Main] 알림 클릭: $payload');
      // TODO: 페이로드를 처리하여 적절한 화면으로 이동
    },
  );
  
  // FCM 초기화 (Firebase 설정이 완료된 경우에만 작동)
  try {
    // ⚠️ 중요: Firebase.initializeApp() 먼저 호출해야
    //    onBackgroundMessage() 등록이 가능함
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 백그라운드 메시지 핸들러는 Firebase 초기화 후에 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // FCM 토큰 발급 및 포그라운드 메시지 리스너 설정
    await FCMService().initialize();
    print('✅ FCM 기능이 활성화되었습니다.');
  } catch (e) {
    print('⚠️ FCM 초기화 실패: $e');
  }
  
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
            navigatorKey: navigatorKey, // 딥링크 처리용 네비게이터 키
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
             home: const SplashScreen(), // 스플래시 화면으로 변경하여 자동 로그인 체크
          );
        },
      ),
    );
  }
}

/// 자동 로그인을 체크하는 스플래시 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AppLinks _appLinks;
  StreamSubscription? _deepLinkSub;
  
  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkAutoLogin();
  }
  
  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }
  
  // 딥링크 초기화
  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // 앱이 실행 중일 때 딥링크 수신
    _deepLinkSub = _appLinks.uriLinkStream.listen((Uri uri) {
      print('🔗 [DeepLink] 수신: $uri');
      _handleDeepLink(uri);
    }, onError: (err) {
      print('❌ [DeepLink] 에러: $err');
    });
    
    // 앱이 종료된 상태에서 딥링크로 실행된 경우
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        print('🔗 [DeepLink] 초기 링크: $uri');
        _handleDeepLink(uri);
      }
    });
  }
  
  // 딥링크 처리
  void _handleDeepLink(Uri uri) {
    print('🔗 [DeepLink] 처리 시작: ${uri.toString()}');
    print('   Scheme: ${uri.scheme}');
    print('   Host: ${uri.host}');
    print('   Path: ${uri.path}');
    
    // allsuri://order/{orderId} 또는 https://allsuri.app/order/{orderId}
    if ((uri.scheme == 'allsuri' || uri.scheme == 'https') && 
        (uri.host == 'order' || uri.path.startsWith('/order'))) {
      
      // orderId 추출
      String? orderId;
      if (uri.host == 'order') {
        // allsuri://order/{orderId}
        orderId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      } else {
        // https://allsuri.app/order/{orderId}
        final segments = uri.pathSegments;
        orderId = segments.length > 1 ? segments[1] : null;
      }
      
      if (orderId != null) {
        print('✅ [DeepLink] 오더 ID: $orderId');
        
        // 오더 마켓플레이스로 이동
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).push(
              MaterialPageRoute(
                builder: (_) => const OrderMarketplaceScreen(),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _checkAutoLogin() async {
    await Future.delayed(const Duration(milliseconds: 500)); // 최소 스플래시 시간
    
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Supabase 세션 확인
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      print('✅ [SplashScreen] 기존 세션 발견 - 자동 로그인 시도');
      try {
        // AuthService에서 사용자 정보 로드
        await authService.loadUserFromSession();
        
        if (mounted && authService.isAuthenticated) {
          print('✅ [SplashScreen] 자동 로그인 성공');
          // 홈 화면으로 이동 (역할에 따라 자동으로 대시보드 표시)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
          return;
        }
      } catch (e) {
        print('⚠️ [SplashScreen] 자동 로그인 실패: $e');
      }
    }
    
    // 세션이 없거나 실패한 경우 홈 화면으로 (온보딩/로그인 표시)
    if (mounted) {
      print('ℹ️ [SplashScreen] 세션 없음 - 홈 화면으로 이동');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 또는 앱 이름
            Icon(
              Icons.construction,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              '올수리',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
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

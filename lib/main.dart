import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  // Supabase 초기화 (Auth 포함)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // NotificationService 초기화
  await NotificationService().initialize();
  
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
          const seed = Color(0xFF6750A4);
          final ColorScheme lightScheme = (lightDynamic ??
                  ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light))
              .harmonized();
          final ColorScheme darkScheme = (darkDynamic ??
                  ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark))
              .harmonized();

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
              navigationBarTheme: NavigationBarThemeData(
                elevation: 1,
                indicatorShape: const StadiumBorder(),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                backgroundColor: colorScheme.surface,
                indicatorColor: colorScheme.secondaryContainer,
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
                fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
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
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

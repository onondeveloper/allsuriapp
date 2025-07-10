import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/order_provider.dart';
import 'providers/estimate_provider.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/estimate_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/estimate_dashboard_screen.dart';
import 'screens/business/estimate_requests_screen.dart';
import 'screens/business/my_estimates_screen.dart';
import 'screens/business/estimate_management_screen.dart';
import 'screens/business/transfer_estimate_screen.dart';
import 'screens/business/select_estimate_for_transfer_screen.dart';
import 'screens/business/transferred_estimates_screen.dart';
import 'models/estimate.dart';
import 'screens/business/business_profile_screen.dart';
import 'screens/customer/create_request_screen.dart';
import 'screens/customer/request_list_screen.dart';
import 'screens/customer/my_estimates_screen.dart';
import 'screens/order/my_orders_page.dart';
import 'screens/chat/chat_list_page.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/notification/notification_screen.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase가 이미 초기화된 경우 무시
    print('Firebase already initialized: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.light();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => OrderProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => EstimateProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => OrderService(AuthService())),
        ChangeNotifierProvider(create: (_) => EstimateService(AuthService())),
      ],
      child: MaterialApp.router(
        title: 'Allsuriapp',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8F9FB),
          primaryColor: const Color(0xFF4F8CFF), // 인디고/민트/핑크 등 포인트 컬러
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: const Color(0xFF4F8CFF),
            secondary: const Color(0xFF00C6AE),
            background: const Color(0xFFF8F9FB),
            surface: Colors.white,
          ),
          fontFamily: 'Inter',
          textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
            headlineLarge: GoogleFonts.inter(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
            titleLarge: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            bodyLarge: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.black87),
            bodyMedium: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.black87),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F8CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4F8CFF),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            shadowColor: Colors.black12,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4F8CFF), width: 2),
            ),
            hintStyle: GoogleFonts.notoSansKr(color: Colors.grey, fontSize: 14),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF4F8CFF),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(),
            elevation: 12,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 2,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
            iconTheme: IconThemeData(color: Color(0xFF4F8CFF)),
          ),
          chipTheme: baseTheme.chipTheme.copyWith(
            backgroundColor: const Color(0xFFE3F0FF),
            selectedColor: const Color(0xFF4F8CFF),
            labelStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/business',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const HomeScreen(),
    ),
    // Admin routes
    GoRoute(
      path: '/admin/user-management',
      builder: (context, state) => const UserManagementScreen(),
    ),
    GoRoute(
      path: '/admin/estimate-dashboard',
      builder: (context, state) => const EstimateDashboardScreen(),
    ),
    // Business routes
    GoRoute(
      path: '/business/requests',
      builder: (context, state) => const EstimateRequestsScreen(),
    ),
    GoRoute(
      path: '/business/estimate-requests',
      builder: (context, state) => const EstimateRequestsScreen(),
    ),
    GoRoute(
      path: '/business/my-estimates',
      builder: (context, state) => const MyEstimatesScreen(),
    ),
    GoRoute(
      path: '/business/estimate-management',
      builder: (context, state) => const EstimateManagementScreen(),
    ),
    GoRoute(
      path: '/business/transferred-estimates',
      builder: (context, state) => const TransferredEstimatesScreen(),
    ),
    GoRoute(
      path: '/business/transfer-estimate',
      builder: (context, state) {
        final estimate = state.extra as Estimate?;
        if (estimate != null) {
          return TransferEstimateScreen(estimate: estimate);
        }
        return const SelectEstimateForTransferScreen();
      },
    ),
    GoRoute(
      path: '/business/transfer-estimate/:estimateId',
      builder: (context, state) {
        final estimate = state.extra as Estimate?;
        if (estimate != null) {
          return TransferEstimateScreen(estimate: estimate);
        }
        return const SelectEstimateForTransferScreen();
      },
    ),
    GoRoute(
      path: '/business/profile',
      builder: (context, state) => const BusinessProfileScreen(),
    ),
    // Customer routes
    GoRoute(
      path: '/customer/create-request',
      builder: (context, state) => const CreateRequestScreen(),
    ),
    GoRoute(
      path: '/customer/requests',
      builder: (context, state) => const RequestListScreen(),
    ),
    GoRoute(
      path: '/customer/my-estimates',
      builder: (context, state) => const CustomerMyEstimatesScreen(),
    ),
    // Common routes
    GoRoute(
      path: '/orders',
      builder: (context, state) {
        final userId = state.uri.queryParameters['userId'] ?? '';
        final role = state.uri.queryParameters['role'] ?? 'customer';
        return MyOrdersPage(
          currentUserId: userId,
          currentUserRole: role,
        );
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatListPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
  ],
);

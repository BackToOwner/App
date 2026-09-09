import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/found_screen.dart';
import 'screens/lost_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api/api_client.dart';
import 'services/auth/api_auth_service.dart';
import 'services/auth/auth_service_interface.dart';
import 'services/repository/api_report_repository.dart';
import 'services/repository/report_repository_interface.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/notifications_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/stats_viewmodel.dart';
import 'viewmodels/support_viewmodel.dart';

/// Lets the API client bounce the user to the auth screen when a session dies mid-use, without
/// every screen having to check for it.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BackToOwnerApp());
}

class BackToOwnerApp extends StatefulWidget {
  const BackToOwnerApp({super.key});

  @override
  State<BackToOwnerApp> createState() => _BackToOwnerAppState();
}

class _BackToOwnerAppState extends State<BackToOwnerApp> {
  late final ApiClient _apiClient;
  late final ApiAuthService _authService;
  late final ApiReportRepository _reportRepository;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authService = ApiAuthService(_apiClient);
    _reportRepository = ApiReportRepository(_apiClient);

    _apiClient.onSessionExpired = () {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Infrastructure
        Provider<ApiClient>.value(value: _apiClient),

        // 2. Services & repositories (abstractions registered first — DIP)
        Provider<IAuthService>.value(value: _authService),
        ListenableProvider<IReportRepository>.value(value: _reportRepository),

        // 3. ViewModels, receiving the injected abstractions
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(context.read<IAuthService>()),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (context) => DashboardViewModel(context.read<IReportRepository>()),
        ),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (context) => ProfileViewModel(context.read<ApiClient>(), context.read<IAuthService>()),
        ),
        ChangeNotifierProvider<NotificationsViewModel>(
          create: (context) => NotificationsViewModel(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<StatsViewModel>(
          create: (context) => StatsViewModel(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<SupportViewModel>(
          create: (context) => SupportViewModel(context.read<ApiClient>()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Back To Owner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            primary: AppColors.primaryBlue,
            secondary: AppColors.primaryCyan,
            surface: AppColors.scaffoldBackground,
          ),
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
          scaffoldBackgroundColor: AppColors.scaffoldBackground,
        ),
        // Starts on the splash screen, which restores a stored session before deciding whether
        // the user sees the dashboard or the sign-in form.
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/auth': (context) => const AuthScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/lost': (context) => const LostScreen(),
          '/found': (context) => const FoundScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

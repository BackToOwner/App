import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/found_screen.dart';
import 'screens/lost_screen.dart';
import 'screens/privacy_notice_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api/api_client.dart';
import 'services/auth/api_auth_service.dart';
import 'services/auth/auth_service_interface.dart';
import 'services/repository/api_report_repository.dart';
import 'services/repository/report_repository_interface.dart';
import 'controllers/auth_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/chat_unread_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/stats_controller.dart';
import 'controllers/support_controller.dart';

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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  late final ApiClient _apiClient;
  late final ApiAuthService _authService;
  late final ApiReportRepository _reportRepository;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object error) {},
    );
    unawaited(_handleInitialLink());

    _apiClient = ApiClient();
    _authService = ApiAuthService(_apiClient);
    _reportRepository = ApiReportRepository(_apiClient);

    _apiClient.onSessionExpired = () {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/auth',
        (route) => false,
      );
    };
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingLink(uri);
    } catch (_) {
      // No initial deep link is normal when launching the app directly.
    }
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    if (uri.scheme != 'backtoowner' || uri.host != 'login-callback') return;

    Map<String, String> fragmentParams = {};
    try {
      fragmentParams = Uri.splitQueryString(uri.fragment);
    } catch (_) {
      // A malformed fragment will be reported as an incomplete session below.
    }

    final params = <String, String>{...uri.queryParameters, ...fragmentParams};

    final navigator = navigatorKey.currentState;
    if (navigator == null || !mounted) return;

    final callbackError = params['error_description'] ?? params['error'];

    if (callbackError != null && callbackError.isNotEmpty) {
      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                'Email confirmation failed: ${Uri.decodeComponent(callbackError.replaceAll('+', ' '))}',
              ),
            ),
          );
        }
      });
      return;
    }

    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'The confirmation link did not provide a complete session. Please sign in or request a new confirmation email.',
              ),
            ),
          );
        }
      });
      return;
    }

    try {
      await _authService.confirmEmail(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      if (!mounted) return;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/privacy-notice',
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('Email confirmed successfully!')),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/auth',
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(error.toString())));
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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

        // 3. Controllers, receiving the injected abstractions
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(context.read<IAuthService>()),
        ),
        ChangeNotifierProvider<DashboardController>(
          create: (context) =>
              DashboardController(context.read<IReportRepository>()),
        ),
        ChangeNotifierProvider<ProfileController>(
          create: (context) => ProfileController(
            context.read<ApiClient>(),
            context.read<IAuthService>(),
          ),
        ),
        ChangeNotifierProvider<NotificationsController>(
          create: (context) =>
              NotificationsController(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<ChatUnreadController>(
          create: (context) => ChatUnreadController(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<StatsController>(
          create: (context) => StatsController(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<SupportController>(
          create: (context) => SupportController(context.read<ApiClient>()),
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
          '/privacy-notice': (context) => const PrivacyNoticeScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/lost': (context) => const LostScreen(),
          '/found': (context) => const FoundScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/found_screen.dart';
import 'screens/lost_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth/auth_service_interface.dart';
import 'services/auth/mock_auth_service.dart';
import 'services/repository/in_memory_report_repository.dart';
import 'services/repository/report_repository_interface.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BackToOwnerApp());
}

class BackToOwnerApp extends StatelessWidget {
  const BackToOwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Services & Repositories (Abstractions registered first - DIP)
        Provider<IAuthService>(create: (_) => MockAuthService()),
        ListenableProvider<IReportRepository>(create: (_) => InMemoryReportRepository()),

        // 2. ViewModels receiving injected Service & Repository abstractions
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<IAuthService>(),
          ),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (context) => DashboardViewModel(
            context.read<IReportRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
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
          textTheme: GoogleFonts.interTextTheme(
            Theme.of(context).textTheme,
          ),
          scaffoldBackgroundColor: AppColors.scaffoldBackground,
        ),
        initialRoute: '/auth',
        routes: {
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

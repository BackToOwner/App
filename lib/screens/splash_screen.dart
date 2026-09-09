import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth/auth_service_interface.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Decides where the app opens.
///
/// A stored refresh token lasts 30 days, so a returning user should not have to sign in again.
/// This restores that session before the first real screen renders — otherwise the dashboard
/// would flash empty and then repopulate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final authService = context.read<IAuthService>();

    try {
      final user = await authService.restoreSession();

      if (!mounted) return;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      }

      context.read<ProfileViewModel>().setUser(user);
      // Warm the feed so the dashboard has content on its first frame.
      await context.read<DashboardViewModel>().refresh();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (_) {
      // An unreachable backend must not trap the user on a spinner — let them reach the sign-in
      // screen, where the real error will be shown when they try.
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavyDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2652).withAlpha(220),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
              ),
              child: Image.asset('assets/images/app_logo.png', errorBuilder: (_, e, s) {
                return const Icon(Icons.search, color: Colors.white, size: 40);
              }),
            ),
            const SizedBox(height: 28),
            const Text(
              'Back To Owner',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            if (_error == null)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryCyan),
              )
            else
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

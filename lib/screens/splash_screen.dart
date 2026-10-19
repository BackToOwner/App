import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth/auth_service_interface.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/profile_controller.dart';

/// Decides where the app opens.
///
/// Features an elegant brand splash design with the official app logo,
/// smooth entrance animation, version number display, and session restoration.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String appVersion = '1.0.0';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final authService = context.read<IAuthService>();
    final stopwatch = Stopwatch()..start();

    try {
      final user = await authService.restoreSession();

      if (user != null && mounted) {
        context.read<ProfileController>().setUser(user);
        // Warm the feed so the dashboard has content on its first frame.
        try {
          await context.read<DashboardController>().refresh();
        } catch (_) {
          // Feed warming failure should not block dashboard entry
        }
      }

      // Keep splash view visible for a few seconds (3.5s) so the user can enjoy the splash design
      const minDisplayMs = 3500;
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < minDisplayMs) {
        await Future<void>.delayed(Duration(milliseconds: minDisplayMs - elapsed));
      }

      if (!mounted) return;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/auth');
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (_) {
      // An unreachable backend must not trap the user on a spinner — let them reach the sign-in
      // screen, where the real error will be shown when they try.
      const minDisplayMs = 3500;
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < minDisplayMs) {
        await Future<void>.delayed(Duration(milliseconds: minDisplayMs - elapsed));
      }
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavyDeep,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withAlpha(35),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCyan.withAlpha(25),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo with glowing card container
                    Container(
                      width: 108,
                      height: 108,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2652), Color(0xFF091733)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.primaryCyan.withAlpha(90),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withAlpha(70),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryCyan,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    const Text(
                      'Back To Owner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle / Tagline
                    Text(
                      'LOST & FOUND PLATFORM',
                      style: TextStyle(
                        color: AppColors.primaryCyan.withAlpha(220),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Loading State
                    if (_error == null)
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: AppColors.primaryCyan,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom App Version
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Version ${SplashScreen.appVersion}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure Community Network',
                      style: TextStyle(
                        color: Colors.white.withAlpha(90),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

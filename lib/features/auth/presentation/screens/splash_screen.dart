import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

// ── Splash screen — §01 per the MD spec ───────────────────────────────────────
// Route /
// Flow:
//   1. Status bar goes transparent (immersive blue).
//   2. Logo + loader animate in (fade + scale).
//   3. Read token from SecureStorage.
//   4. Token valid   → navigate to /dashboard
//      Token missing → navigate to /login
//
// The minimum display duration (1.2 s) ensures the animation completes even on
// very fast devices so the brand moment isn't skipped.

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.onNavigate});

  // Callback injected by the router. Receives 'dashboard' or 'login'.
  final void Function(String destination)? onNavigate;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    // Immersive: transparent status bar over the blue background.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: mbBlue,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Fade + scale-up animation for logo entry.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Minimum splash time so the animation plays fully.
    final minDelay = Future.delayed(const Duration(milliseconds: 1400));

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final token = await storage.read(key: 'mb_bearer_token');

    await minDelay; // wait for whichever is longer

    if (!mounted) return;

    final destination = (token != null && token.isNotEmpty) ? 'dashboard' : 'login';
    widget.onNavigate?.call(destination);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mbBlue,
      body: Stack(
        children: [
          // ── Centered: logo + loader ──────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logo_white.png',
                      width: _logoWidth(context),
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 60),

                    // Thin white circular progress indicator
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Color(0x33FFFFFF), // white 20%
                        strokeWidth: 2.2,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Version — bottom center ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: FadeTransition(
              opacity: _opacity,
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: MbTypography.mono(Colors.white.withAlpha(0x66)), // white 40%
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logo fills 62% of screen width, capped at 280 for tablets.
  double _logoWidth(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    return (sw * 0.62).clamp(160.0, 280.0);
  }
}

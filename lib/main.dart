import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'update_service.dart';
import 'utils/pwa_check.dart';
import 'install_prompt_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0D1622),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0D1622),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const WordifyApp());
}

class WordifyApp extends StatelessWidget {
  const WordifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF137FEC),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1622),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1622),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF0D1622),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF131D36),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: Color(0xFF0C1322),
              width: 1.2,
            ),
          ),
          insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
        useMaterial3: true,
      ),
      home: const WordifyRootRouter(),
    );
  }
}

class WordifyRootRouter extends StatefulWidget {
  const WordifyRootRouter({super.key});

  @override
  State<WordifyRootRouter> createState() => _WordifyRootRouterState();
}

class _WordifyRootRouterState extends State<WordifyRootRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobileWeb = kIsWeb && isMobileBrowser();
    if (isMobileWeb && !isPWA()) {
      return const InstallPromptPage();
    }

    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1128),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3A86FF),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const WordifyHomePage();
        }

        return const LoginPage();
      },
    );
  }
}

class WordifyHomePage extends StatefulWidget {
  const WordifyHomePage({super.key});

  @override
  State<WordifyHomePage> createState() => _WordifyHomePageState();
}

class _WordifyHomePageState extends State<WordifyHomePage> {
  int _currentDay = 77;
  final int _totalDays = 611;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1622),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1622),
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.translate,
              color: Color(0xFF137FEC),
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Wordify',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Color(0xFF6E8FB0), size: 26),
              tooltip: 'Ayarlar',
              onPressed: () => _openSettings(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF1E293B),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Center Circle with Progress Border and Info Badge
                SizedBox(
                  width: 270,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated Circular Progress Border
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: (_currentDay / _totalDays).clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedProgress, child) {
                          return CustomPaint(
                            size: const Size(236, 236),
                            painter: _ProgressRingPainter(
                              progress: animatedProgress,
                              trackColor: const Color(0xFF334155),
                              progressColor: const Color(0xFF137FEC),
                              strokeWidth: 6.0,
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              'Gün $_currentDay',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Floating Info Badge
                      Positioned(
                        top: 8,
                        right: 18,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF324154),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.info_outline,
                              color: Color(0xFF6E8FB0),
                              size: 19,
                            ),
                            tooltip: 'Bilgi',
                            onPressed: () {
                              AppToast.show(
                                context,
                                message: '$_currentDay. gün içeriği',
                                backgroundColor: const Color(0xFF1E293B),
                                icon: Icons.info_outline,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                // "Başla" Button
                ElevatedButton(
                  onPressed: () {
                    AppToast.show(
                      context,
                      message: '$_currentDay. güne başlandı!',
                      backgroundColor: const Color(0xFF137FEC),
                      icon: Icons.play_arrow_rounded,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Başla',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Pagination Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous Day Button
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF324154),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      onPressed: _currentDay > 1
                          ? () => setState(() => _currentDay--)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Current / Total Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF324154),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$_currentDay / $_totalDays',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Next Day Button
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF324154),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      onPressed: _currentDay < _totalDays
                          ? () => setState(() => _currentDay++)
                          : null,
                    ),
                  ],
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress Border
    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

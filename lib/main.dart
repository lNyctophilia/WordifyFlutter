import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'version.dart';
import 'update_service.dart';
import 'utils/pwa_check.dart';
import 'install_prompt_page.dart';
import 'login_page.dart';

import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131D36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, color: Color(0xFF3A86FF)),
              SizedBox(width: 10),
              Text(
                'Ayarlar',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Builder(
            builder: (context) {
              final user = AuthService.currentUser;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1128),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF3A86FF),
                            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                            child: user.photoURL == null
                                ? Text(
                                    (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'Google Kullanıcısı',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email ?? '',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Text(
                    'Uygulama Tercihleri',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined, color: Colors.white70),
                    title: const Text('Tema', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Koyu Tema (Aktif)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    onTap: () {},
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline, color: Colors.white70),
                    title: const Text('Sürüm Bilgisi', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      AppConfig.fullVersionString,
                      style: const TextStyle(color: Color(0xFF3A86FF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync_rounded, color: Colors.white70),
                    title: const Text('Güncellemeleri Denetle', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Sunucudaki en son sürümü kontrol eder', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      UpdateService.checkForUpdates(context, showNoUpdateMessage: true);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent),
                    title: const Text('Çerezleri ve Önbelleği Temizle', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Eski verileri sıfırlar ve sayfayı yeniler', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      UpdateService.clearCacheAndReload();
                    },
                  ),
                  if (user != null) ...[
                    const Divider(color: Colors.white10, height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      title: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Hesabınızdan güvenle çıkış yapın', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await AuthService.signOut();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kapat', style: TextStyle(color: Color(0xFF3A86FF))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1622),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
              onPressed: () => _showSettingsDialog(context),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$_currentDay. gün içeriği'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF1E293B),
                                ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$_currentDay. güne başlandı!'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF137FEC),
                      ),
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

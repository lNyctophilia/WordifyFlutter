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

import 'dart:async';
import 'auth_service.dart';
import 'progress_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A1128),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A1128),
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
          seedColor: const Color(0xFF3A86FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1128),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1128),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF0A1128),
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
  // Demo stat data for the new UI
  final int _streak = 12;
  final int _totalLearned = 340;
  final int _newWordsGoal = 10;
  final int _newWordsDone = 0;
  final int _reviewGoal = 25;
  final int _reviewDone = 0;

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

  void _startSession() {
    AppToast.show(
      context,
      message: 'Güne Başlandı!',
      backgroundColor: const Color(0xFF3A86FF),
      icon: Icons.rocket_launch_rounded,
    );
    // TODO: Navigate to Session UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1128),
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.translate,
              color: Color(0xFF3A86FF),
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
              icon: const Icon(Icons.settings_outlined, color: Color(0xFF7A9BB8), size: 26),
              tooltip: 'Ayarlar',
              onPressed: () => _openSettings(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF192540),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upper Part: Streak & Total Learned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orangeAccent,
                          value: '$_streak Gün',
                          label: 'Seri',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.school_rounded,
                          iconColor: const Color(0xFF3A86FF),
                          value: '$_totalLearned',
                          label: 'Öğrenilen',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Main Task Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D36).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Bugünün Hedefi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Progress Bars
                        _buildProgressBar(
                          title: 'Yeni Kelimeler',
                          current: _newWordsDone,
                          total: _newWordsGoal,
                          color: const Color(0xFF3A86FF),
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(height: 24),
                        _buildProgressBar(
                          title: 'Tekrarlar (Review)',
                          current: _reviewDone,
                          total: _reviewGoal,
                          color: const Color(0xFF00E676),
                          icon: Icons.refresh_rounded,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Start Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3A86FF).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3A86FF), Color(0xFF00B4D8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _startSession,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Güne Başla',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Bottom Part: Activity or Stats Summary
                  const Text(
                    'Haftalık Aktivite',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildWeeklyActivityGraph(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E2D4A),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String title,
    required int current,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final progress = total > 0 ? current / total : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '$current / $total',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF1E2D4A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivityGraph() {
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final activity = [0.4, 0.7, 0.5, 0.9, 0.2, 0.0, 0.0];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1E2D4A),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          return Column(
            children: [
              Container(
                width: 24,
                height: 100,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D4A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FractionallySizedBox(
                  heightFactor: activity[index],
                  child: Container(
                    decoration: BoxDecoration(
                      color: activity[index] > 0 ? const Color(0xFF3A86FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                days[index],
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

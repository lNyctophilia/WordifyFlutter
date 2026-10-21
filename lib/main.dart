import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'update_service.dart';
import 'utils/pwa_check.dart';
import 'utils/sound_service.dart';
import 'utils/tts_service.dart';
import 'install_prompt_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'session_page.dart';
import 'models/exercise_types.dart';
import 'spaced_repetition_service.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  SoundService.init();
  TtsService.init();

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
  int? _selectedDay;
  int? _lastDbDay;
  int _currentActiveDay = 1;
  VoidCallback? _latestStartAction;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        if (_selectedDay != null) {
          SpacedRepetitionService.setCurrentDay(_selectedDay!);
        }
      },
      onDetach: () {
        if (_selectedDay != null) {
          SpacedRepetitionService.setCurrentDay(_selectedDay!);
        }
      },
      onHide: () {
        if (_selectedDay != null) {
          SpacedRepetitionService.setCurrentDay(_selectedDay!);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
      SpacedRepetitionService.initMockDataIfEmpty();
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_currentActiveDay > 1) {
        final prev = _currentActiveDay - 1;
        setState(() {
          _selectedDay = prev;
          _lastDbDay = prev;
        });
        SpacedRepetitionService.setCurrentDay(prev);
        return true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = _currentActiveDay + 1;
      setState(() {
        _selectedDay = next;
        _lastDbDay = next;
      });
      SpacedRepetitionService.setCurrentDay(next);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _latestStartAction?.call();
      return true;
    }
    return false;
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
    if (mounted) {
      final currentDay = await SpacedRepetitionService.getCurrentDay();
      setState(() {
        _selectedDay = currentDay;
        _lastDbDay = currentDay;
      });
    }
  }

  void _startSession(int day, SessionPart part) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionPage(day: day, part: part),
      ),
    );
  }

  Future<void> _showRestartConfirmationDialog(BuildContext context, int day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              Navigator.of(ctx).pop(true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
              Navigator.of(ctx).pop(true),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(ctx).pop(false),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            backgroundColor: const Color(0xFF131D36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: const Row(
              children: [
                Icon(Icons.refresh_rounded, color: Color(0xFF00E676)),
                SizedBox(width: 10),
                Text(
                  'Eğitimi Baştan Başlat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Eğitimi bitirdiniz. Baştan başlansın mı?\n\nEvet derseniz bugünün verileri silinip en baştan başlanacaktır.',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Hayır', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Evet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await SpacedRepetitionService.resetDayProgress(day);
      if (mounted) {
        _startSession(day, SessionPart.part1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: SpacedRepetitionService.getUserProfileStream(),
      builder: (context, profileSnapshot) {
        if (!profileSnapshot.hasData && _selectedDay == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1128),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3A86FF),
              ),
            ),
          );
        }

        final profile = profileSnapshot.data ?? {};
        final dbDay = (profile['current_day'] as num?)?.toInt() ??
            (profile['currentDay'] as num?)?.toInt() ??
            _selectedDay ??
            1;

        if (_selectedDay == null || (_lastDbDay != null && _lastDbDay != dbDay)) {
          _selectedDay = dbDay;
        }
        _lastDbDay = dbDay;
        final activeDay = _selectedDay!;
        _currentActiveDay = activeDay;
        final streak = (profile['streak'] as num?)?.toInt() ?? 0;

        return StreamBuilder<Map<String, int>>(
          stream: SpacedRepetitionService.getStatsStreamForDay(activeDay),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {'total_learned': 0};
            final int totalLearned = stats['total_learned'] ?? 0;

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 40).clamp(0.0, double.infinity),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                                  value: '$streak Gün',
                                  label: 'Seri',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatBadge(
                                  icon: Icons.school_rounded,
                                  iconColor: const Color(0xFF3A86FF),
                                  value: '$totalLearned',
                                  label: 'Öğrenilen',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Day Navigation Switcher
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131D36),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                  tooltip: 'Önceki Gün',
                                  onPressed: activeDay > 1
                                      ? () {
                                          final prev = activeDay - 1;
                                          setState(() {
                                            _selectedDay = prev;
                                            _lastDbDay = prev;
                                          });
                                          SpacedRepetitionService.setCurrentDay(prev);
                                        }
                                      : null,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Gün $activeDay',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeDay == 1 ? 'Başlangıç Günü' : 'Eğitim & Tekrar',
                                      style: const TextStyle(
                                        color: Color(0xFF3A86FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                                  tooltip: 'Sonraki Gün',
                                  onPressed: () {
                                    final next = activeDay + 1;
                                    setState(() {
                                      _selectedDay = next;
                                      _lastDbDay = next;
                                    });
                                    SpacedRepetitionService.setCurrentDay(next);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Main Task Card
                          StreamBuilder<DayProgress>(
                            stream: SpacedRepetitionService.getDayProgressStream(activeDay),
                            builder: (context, partSnap) {
                              final dayProgress = partSnap.data ?? DayProgress(dayType: SpacedRepetitionService.getDayType(activeDay));
                              final allDone = dayProgress.isCompleted;
                              final nextPart = dayProgress.nextPart ?? SessionPart.part1;
                              final completedParts = dayProgress.completedParts;
                              final dayType = SpacedRepetitionService.getDayType(activeDay);

                              void startAction() {
                                if (allDone) {
                                  _showRestartConfirmationDialog(context, activeDay);
                                } else {
                                  _startSession(activeDay, nextPart);
                                }
                              }
                              _latestStartAction = startAction;

                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131D36).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Gün başlığı + tip
                                    Column(
                                      children: [
                                        Text(
                                          'Gün $activeDay',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: dayType == DayType.review
                                                ? const Color(0xFF00E676).withValues(alpha: 0.12)
                                                : const Color(0xFF3A86FF).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            dayType == DayType.review ? '🔄 Tekrar Günü' : '📘 Öğrenme Günü',
                                            style: TextStyle(
                                              color: dayType == DayType.review
                                                  ? const Color(0xFF00E676)
                                                  : const Color(0xFF3A86FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Part durumları (4 chip)
                                    _buildPartStatusRow(
                                      completedParts: completedParts,
                                      totalParts: dayProgress.totalParts,
                                    ),

                                    const SizedBox(height: 24),

                                    // İlerleme çubuğu
                                    _buildProgressBar(
                                      title: 'Günlük İlerleme',
                                      current: completedParts,
                                      total: dayProgress.totalParts,
                                      color: allDone ? const Color(0xFF00E676) : const Color(0xFF3A86FF),
                                      icon: allDone ? Icons.check_circle_rounded : Icons.school_rounded,
                                      isCompleted: allDone,
                                    ),

                                    const SizedBox(height: 28),

                                    // Start / Continue Button
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: allDone
                                            ? const LinearGradient(
                                                colors: [Color(0xFF00E676), Color(0xFF00B4D8)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : const LinearGradient(
                                                colors: [Color(0xFF3A86FF), Color(0xFF00B4D8)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: startAction,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          disabledBackgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 32, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              allDone
                                                  ? 'Eğitimi Tekrarla'
                                                  : completedParts == 0
                                                      ? 'Eğitime Başla'
                                                      : 'Part ${completedParts + 1}\'den Devam Et',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Icon(
                                              allDone
                                                  ? Icons.refresh_rounded
                                                  : Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
          },
        );
      },
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

  Widget _buildPartStatusRow({
    required int completedParts,
    required int totalParts,
  }) {
    final partColors = [
      const Color(0xFF3A86FF),
      const Color(0xFF7209B7),
      const Color(0xFF00E676),
      const Color(0xFFFFB703),
    ];
    final partLabels = ['P1', 'P2', 'P3', 'P4'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < totalParts; i++) ...[
          _partChip(
            label: partLabels[i],
            done: i < completedParts,
            color: partColors[i],
          ),
          if (i < totalParts - 1)
            Container(
              width: 20,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: i < completedParts
                  ? partColors[i].withValues(alpha: 0.5)
                  : const Color(0xFF1E2D4A),
            ),
        ],
      ],
    );
  }

  Widget _partChip({
    required String label,
    required bool done,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.2) : const Color(0xFF0A1128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? color : const Color(0xFF1E2D4A),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            Icon(Icons.check_rounded, color: color, size: 14)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF1E2D4A),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: done ? color : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
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
    bool isCompleted = false,
  }) {
    final bool completed =
        isCompleted || total == 0 || (total > 0 && current >= total);
    final double progress = completed
        ? 1.0
        : (total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0);

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$current / $total',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (completed) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    color: color,
                    size: 16,
                  ),
                ],
              ],
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

}

import 'package:flutter/material.dart';
import 'dart:math';
import 'spaced_repetition_service.dart';

enum QuestionType { partial, mastery }

class SessionQuestion {
  final QuestionType type;
  final String sentence;
  final String sentenceTr;
  final String translation;
  final String targetWord;
  final String hint;
  final Map<String, String>? falseFriends;

  SessionQuestion({
    required this.type,
    required this.targetWord,
    this.sentence = '',
    this.sentenceTr = '',
    this.translation = '',
    this.hint = '',
    this.falseFriends,
  });
}

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with SingleTickerProviderStateMixin {
  List<SpacedWord> _words = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  bool _showFeedback = false;
  String? _falseFriendWarning;
  bool _isCorrect = false;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final words = await SpacedRepetitionService.getTodaySession();
      if (mounted) {
        setState(() {
          _words = words;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kelime yüklenirken bir hata oluştu: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  SessionQuestion _mapToQuestion(SpacedWord w) {
    // Partial hint generation (e.g. "word" -> "w _ _ _")
    String hint = '';
    if (w.wordEn.isNotEmpty) {
      if (w.step <= 1) {
        // More hint for beginners
        hint = w.wordEn[0] + ' ' + List.generate(w.wordEn.length - 1, (_) => '_').join(' ');
      } else {
        // Harder hint
        hint = w.wordEn[0] + List.generate(w.wordEn.length - 1, (_) => ' _').join('');
      }
    }

    if (w.step <= 3) {
      return SessionQuestion(
        type: QuestionType.partial,
        targetWord: w.wordEn,
        translation: w.wordTr,
        sentence: w.exampleSentence ?? '',
        sentenceTr: w.exampleTr ?? '',
        hint: hint,
      );
    } else {
      return SessionQuestion(
        type: QuestionType.mastery,
        targetWord: w.wordEn,
        translation: w.wordTr,
      );
    }
  }

  void _checkAnswer(String answer) {
    if (_showFeedback || answer.isEmpty) return;

    final currentWord = _words[_currentIndex];
    final currentQ = _mapToQuestion(currentWord);
    final isCorrect = answer.toLowerCase().trim() == currentQ.targetWord.toLowerCase();

    // Update progress in Firestore in background
    SpacedRepetitionService.updateWordProgress(currentWord.id, isCorrect);

    if (isCorrect) {
      setState(() {
        _isCorrect = true;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        _nextQuestion();
      });
    } else {
      _shakeController.forward(from: 0.0);
      
      String? falseFriend;
      final ans = answer.toLowerCase().trim();
      if (currentQ.falseFriends != null && currentQ.falseFriends!.containsKey(ans)) {
        falseFriend = "Senin yazdığın '$ans' kelimesi '${currentQ.falseFriends![ans]}' anlamına gelir.";
      }

      setState(() {
        _isCorrect = false;
        _showFeedback = true;
        _falseFriendWarning = falseFriend;
      });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;
    
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _showFeedback = false;
        _isCorrect = false;
        _textController.clear();
      });
      
      Future.delayed(const Duration(milliseconds: 100), () {
        _focusNode.requestFocus();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF131D36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.amber, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Harika İş Çıkardın!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bugünkü hedeflerini tamamladın. Yarın görüşmek üzere!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A86FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ana Sayfaya Dön', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1128),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF3A86FF))),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1128),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Bugünlük çalışılacak kelime yok!\nYarın tekrar gel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
          ),
        ),
      );
    }

    final progress = (_currentIndex) / _words.length;
    final currentQ = _mapToQuestion(_words[_currentIndex]);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF1E2D4A),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A86FF)),
            minHeight: 6,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final sine = sin(_shakeController.value * 4 * pi);
                          return Transform.translate(
                            offset: Offset(sine * 8, 0),
                            child: child,
                          );
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _buildCard(currentQ, key: ValueKey(_currentIndex)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Smart Feedback Overlay
            if (_showFeedback)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) {
                    return FractionalTranslation(
                      translation: offset,
                      child: child,
                    );
                  },
                  child: _buildFeedbackCard(currentQ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(SessionQuestion q, {required Key key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _isCorrect ? const Color(0xFF00E676).withValues(alpha: 0.1) : const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _isCorrect ? const Color(0xFF00E676).withValues(alpha: 0.5) : const Color(0xFF1E2D4A),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isCorrect ? const Color(0xFF00E676).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            q.translation,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3A86FF), fontSize: 26, fontWeight: FontWeight.bold),
          ),
          
          if (q.type == QuestionType.partial) ...[
            const SizedBox(height: 24),
            if (q.sentenceTr.isNotEmpty)
              Text(
                q.sentenceTr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16, fontStyle: FontStyle.italic),
              ),
            if (q.sentence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                q.sentence,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ],
            if (q.hint.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                q.hint,
                style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
              ),
            ],
          ] else if (q.type == QuestionType.mastery) ...[
            const SizedBox(height: 16),
            const Icon(Icons.school_rounded, color: Color(0xFF3A86FF), size: 48),
          ],
          
          const SizedBox(height: 48),
          
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: 'İngilizcesini yazın...',
              hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 0, fontSize: 18),
              filled: true,
              fillColor: const Color(0xFF0A1128),
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF3A86FF), width: 2),
              ),
            ),
            onSubmitted: _checkAnswer,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _checkAnswer(_textController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Kontrol Et', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(SessionQuestion q) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131D36),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.redAccent, width: 2)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.redAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yanlış Cevap', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Doğrusu: ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                            TextSpan(text: q.targetWord, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_falseFriendWarning != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _falseFriendWarning!,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2D4A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Anladım (Devam Et)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

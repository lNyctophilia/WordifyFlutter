import 'package:flutter/material.dart';
import 'dart:math';
import 'spaced_repetition_service.dart';

enum QuestionType {
  /// Aşama 1: Tanıma (Recognition) - 1. ve 2. Tekrarlar (Adım 0-1)
  /// 4 şıklı çoktan seçmeli cloze testi
  recognition,

  /// Aşama 2: Kısmi Üretme (Partial Production) - 3. ve 4. Tekrarlar (Adım 2-3)
  /// Cümle boşluğu + ilk harf ve uzunluk ipucu ile klavye girişi
  partial,

  /// Aşama 3: Tam Ustalık (Mastery) - 5. Tekrar ve sonrası (Adım 4+)
  /// İpucu yok, sadece Türkçe anlam verilir, kelimenin tamamı yazılır
  mastery,
}

class SessionQuestion {
  final QuestionType type;
  final String targetWord;
  final String translation;
  final String sentence;
  final String sentenceTr;
  final String hint;
  final List<String> options;

  SessionQuestion({
    required this.type,
    required this.targetWord,
    required this.translation,
    this.sentence = '',
    this.sentenceTr = '',
    this.hint = '',
    this.options = const [],
  });
}

class SessionPage extends StatefulWidget {
  final int day;

  const SessionPage({
    super.key,
    this.day = 1,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with SingleTickerProviderStateMixin {
  List<SpacedWord> _words = [];
  List<SessionQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  bool _showFeedback = false;
  String? _falseFriendWarning;
  bool _isCorrect = false;
  String? _selectedOption;

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
      final words = await SpacedRepetitionService.getSessionForDay(widget.day);
      final questions = words.map(_mapToQuestion).toList();

      if (mounted) {
        setState(() {
          _words = words;
          _questions = questions;
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
    String sentence = w.exampleSentence ?? '';
    if (sentence.isEmpty) {
      sentence = '_____';
    } else if (!sentence.contains('_____')) {
      sentence = sentence.replaceAll(
        RegExp(RegExp.escape(w.wordEn), caseSensitive: false),
        '_____',
      );
    }

    if (w.step <= 1) {
      // Aşama 1: Tanıma (Recognition) - 4 şıklı çoktan seçmeli
      final distractors = SpacedRepetitionService.getRandomDistractors(w.wordEn, count: 3);
      final options = [w.wordEn, ...distractors]..shuffle();

      return SessionQuestion(
        type: QuestionType.recognition,
        targetWord: w.wordEn,
        translation: w.wordTr,
        sentence: sentence,
        sentenceTr: w.exampleTr ?? '',
        options: options,
      );
    } else if (w.step <= 3) {
      // Aşama 2: Kısmi Üretme (Partial Production) - İlk harf + uzunluk ipucu
      String hint = '';
      if (w.wordEn.isNotEmpty) {
        hint = w.wordEn[0] + List.generate(w.wordEn.length - 1, (_) => ' _').join('');
      }

      return SessionQuestion(
        type: QuestionType.partial,
        targetWord: w.wordEn,
        translation: w.wordTr,
        sentence: sentence,
        sentenceTr: w.exampleTr ?? '',
        hint: hint,
      );
    } else {
      // Aşama 3: Tam Ustalık (Mastery) - İpuçsuz doğrudan çeviri
      return SessionQuestion(
        type: QuestionType.mastery,
        targetWord: w.wordEn,
        translation: w.wordTr,
        sentenceTr: w.exampleTr ?? '',
      );
    }
  }

  void _checkAnswer(String rawAnswer) {
    if (_showFeedback || _questions.isEmpty) return;
    final answer = rawAnswer.trim();
    if (answer.isEmpty) return;

    final currentWord = _words[_currentIndex];
    final currentQ = _questions[_currentIndex];
    final isCorrect = answer.toLowerCase() == currentQ.targetWord.toLowerCase();

    // SRS ilerlemesini güncelle
    SpacedRepetitionService.updateWordProgress(
      currentWord.id,
      isCorrect,
      activeDay: widget.day,
    );

    if (isCorrect) {
      setState(() {
        _isCorrect = true;
        _selectedOption = answer;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        _nextQuestion();
      });
    } else {
      _shakeController.forward(from: 0.0);

      // Aşama 4: Akıllı Hata Geri Bildirimi (Smart Feedback)
      // Kullanıcının yazdığı veya seçtiği yanlış kelimenin sözlük karşılığını bul
      String? falseFriend;
      final enteredMeaning = SpacedRepetitionService.getWordMeaning(answer);
      if (enteredMeaning != null && enteredMeaning.isNotEmpty) {
        falseFriend = "Senin yazdığın/seçtiğin '$answer' kelimesi '$enteredMeaning' anlamına gelir.";
      }

      setState(() {
        _isCorrect = false;
        _showFeedback = true;
        _selectedOption = answer;
        _falseFriendWarning = falseFriend;
      });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showFeedback = false;
        _isCorrect = false;
        _selectedOption = null;
        _falseFriendWarning = null;
        _textController.clear();
      });

      if (_questions[_currentIndex].type != QuestionType.recognition) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _focusNode.requestFocus();
        });
      }
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
                  'Bugünkü öğrenme ve tekrar görevlerini başarıyla tamamladın.',
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
                    child: const Text(
                      'Ana Sayfaya Dön',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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

    if (_questions.isEmpty) {
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

    final progress = (_currentIndex + 1) / _questions.length;
    final currentQ = _questions[_currentIndex];

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
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
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

            // Aşama 4: Akıllı Hata Geri Bildirimi Alt Kartı
            if (_showFeedback)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
                  duration: const Duration(milliseconds: 250),
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
    String typeBadgeTitle;
    IconData typeBadgeIcon;
    Color typeBadgeColor;

    switch (q.type) {
      case QuestionType.recognition:
        typeBadgeTitle = 'Aşama 1: Tanıma (Çoktan Seçmeli)';
        typeBadgeIcon = Icons.visibility_rounded;
        typeBadgeColor = const Color(0xFF00B4D8);
        break;
      case QuestionType.partial:
        typeBadgeTitle = 'Aşama 2: Kısmi Üretme (İpuçlu Yazma)';
        typeBadgeIcon = Icons.edit_note_rounded;
        typeBadgeColor = const Color(0xFF3A86FF);
        break;
      case QuestionType.mastery:
        typeBadgeTitle = 'Aşama 3: Tam Ustalık (Doğrudan Yazma)';
        typeBadgeIcon = Icons.workspace_premium_rounded;
        typeBadgeColor = const Color(0xFFFFB703);
        break;
    }

    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _isCorrect
            ? const Color(0xFF00E676).withValues(alpha: 0.1)
            : const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _isCorrect
              ? const Color(0xFF00E676).withValues(alpha: 0.5)
              : const Color(0xFF1E2D4A),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isCorrect
                ? const Color(0xFF00E676).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aşama Etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: typeBadgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: typeBadgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeBadgeIcon, size: 16, color: typeBadgeColor),
                const SizedBox(width: 6),
                Text(
                  typeBadgeTitle,
                  style: TextStyle(
                    color: typeBadgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Türkçe Anlam
          Text(
            q.translation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3A86FF),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (q.sentenceTr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              q.sentenceTr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (q.type == QuestionType.recognition || q.type == QuestionType.partial) ...[
            if (q.sentence.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                q.sentence,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ],

          if (q.type == QuestionType.partial && q.hint.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              q.hint,
              style: const TextStyle(
                color: Color(0xFF00B4D8),
                fontSize: 24,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 36),

          // Soru Tipine Göre Giriş / Şık Alanı
          if (q.type == QuestionType.recognition)
            _buildRecognitionOptions(q)
          else
            _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildRecognitionOptions(SessionQuestion q) {
    return Column(
      children: q.options.map((option) {
        final isSelected = _selectedOption?.toLowerCase() == option.toLowerCase();
        final isOptionTarget = option.toLowerCase() == q.targetWord.toLowerCase();

        Color bgColor = const Color(0xFF0A1128);
        Color borderColor = const Color(0xFF1E2D4A);
        Color textColor = Colors.white;

        if (_isCorrect && isOptionTarget) {
          bgColor = const Color(0xFF00E676).withValues(alpha: 0.2);
          borderColor = const Color(0xFF00E676);
          textColor = const Color(0xFF00E676);
        } else if (_showFeedback) {
          if (isOptionTarget) {
            bgColor = const Color(0xFF00E676).withValues(alpha: 0.2);
            borderColor = const Color(0xFF00E676);
            textColor = const Color(0xFF00E676);
          } else if (isSelected) {
            bgColor = Colors.redAccent.withValues(alpha: 0.2);
            borderColor = Colors.redAccent;
            textColor = Colors.redAccent;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: (_showFeedback || _isCorrect) ? null : () => _checkAnswer(option),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField() {
    return Column(
      children: [
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
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
            child: const Text(
              'Kontrol Et',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
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
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.redAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yanlış Cevap',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Doğrusu: ',
                              style: TextStyle(color: Colors.white70, fontSize: 18),
                            ),
                            TextSpan(
                              text: q.targetWord,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 14,
                          height: 1.4,
                        ),
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
              child: const Text(
                'Anladım (Devam Et)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'spaced_repetition_service.dart';
import 'models/exercise_types.dart';
import 'utils/sound_service.dart';
import 'utils/tts_service.dart';
import 'utils/answer_validator.dart';

// ─── SessionPage ───────────────────────────────────────────────────────────

class SessionPage extends StatefulWidget {
  final int day;
  final SessionPart part;

  const SessionPage({
    super.key,
    this.day = 1,
    this.part = SessionPart.part1,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage>
    with SingleTickerProviderStateMixin {
  List<ExerciseQuestion> _questions = [];
  List<SpacedWord> _words = [];
  bool _isLoading = true;
  bool _isPartFinished = false;

  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalAnswered = 0;

  bool _showFeedback = false;
  bool _isCorrect = false;
  String? _selectedAnswer = '';
  String? _falseFriendNote;

  final TextEditingController _textController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  late AnimationController _shakeController;
  Timer? _flashTimer;
  Timer? _transitionTimer;
  bool _correctStroke = false;
  bool _wrongStroke = false;

  // Seans içinde yanlış bilinen kelimeler (bonus için)
  final Map<String, int> _wrongCountMap = {};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    SoundService.init();
    TtsService.init();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadPartQuestions();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _transitionTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _textController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_isPartFinished) {
        _continueFromFinished();
        return true;
      }
      if (_showFeedback) {
        _nextQuestion();
        return true;
      }
    }

    return false;
  }

  // ─── Yükleme ────────────────────────────────────────────────────────────

  Future<void> _loadPartQuestions() async {
    try {
      final words = await SpacedRepetitionService.getWordsForDay(widget.day);
      _words = words;

      if (words.isEmpty) {
        if (mounted) {
          setState(() {
            _questions = [];
            _isLoading = false;
            _isPartFinished = true;
          });
        }
        return;
      }

      final questions = SpacedRepetitionService.buildPartQuestions(words, widget.part);

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        if (_questions.isNotEmpty) {
          _focusWritingInput();
        }
      }
    } catch (e) {
      debugPrint('Error loading part questions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Cevap Kontrolü ───────────────────────────────────────────────────────

  void _checkAnswer(String rawAnswer) {
    if (_showFeedback || _isCorrect || _questions.isEmpty) return;
    final answer = rawAnswer.trim();
    if (answer.isEmpty) return;

    final q = _questions[_currentIndex];
    final bool isCorrect;

    // EN cevap isteniyor → isEnglishCorrect, TR cevap → isTurkishCorrect
    if (q.direction == AnswerDirection.toEnglish) {
      isCorrect = AnswerValidator.isEnglishCorrect(answer, q.wordEn);
    } else {
      isCorrect = AnswerValidator.isTurkishCorrect(answer, q.wordTr);
    }

    _totalAnswered++;

    SpacedRepetitionService.updateWordProgress(
      q.wordId,
      isCorrect,
      activeDay: widget.day,
    );

    if (isCorrect) {
      _correctCount++;
      SoundService.playCorrect();
      // Doğru cevapta → İngilizce kelimeyi seslendir
      TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));

      _flashTimer?.cancel();
      _transitionTimer?.cancel();
      setState(() {
        _isCorrect = true;
        _correctStroke = true;
        _wrongStroke = false;
        _selectedAnswer = answer;
      });
      _flashTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _correctStroke = false);
      });
      _transitionTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) _nextQuestion();
      });
    } else {
      SoundService.playWrong();
      _shakeController.forward(from: 0.0);

      _wrongCountMap[q.wordId] = (_wrongCountMap[q.wordId] ?? 0) + 1;

      // Yanlış bilinen soruyu sona ekle
      _questions.add(SpacedRepetitionService.buildRetryQuestion(q, widget.part));

      // False friend notu
      String? note;
      if (q.direction == AnswerDirection.toEnglish) {
        final enteredMeaning = SpacedRepetitionService.getWordMeaning(answer.toLowerCase());
        if (enteredMeaning != null && enteredMeaning.isNotEmpty) {
          note = "'$answer' → $enteredMeaning anlamına gelir.";
        }
      }

      _flashTimer?.cancel();
      setState(() {
        _isCorrect = false;
        _correctStroke = false;
        _wrongStroke = true;
        _showFeedback = true;
        _selectedAnswer = answer;
        _falseFriendNote = note;
      });
      _flashTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongStroke = false);
      });
    }
  }

  void _focusWritingInput() {
    void tryFocus() {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryFocus());
    Future.delayed(const Duration(milliseconds: 100), tryFocus);
    Future.delayed(const Duration(milliseconds: 250), tryFocus);
    Future.delayed(const Duration(milliseconds: 400), tryFocus);
  }

  void _nextQuestion() {
    if (!mounted) return;

    if (_currentIndex < _questions.length - 1) {
      final oldFocusNode = _focusNode;
      oldFocusNode.unfocus();
      _focusNode = FocusNode();
      Future.delayed(const Duration(milliseconds: 400), () {
        oldFocusNode.dispose();
      });

      setState(() {
        _currentIndex++;
        _showFeedback = false;
        _isCorrect = false;
        _correctStroke = false;
        _wrongStroke = false;
        _selectedAnswer = null;
        _falseFriendNote = null;
        _textController.clear();
      });

      _focusWritingInput();
    } else {
      _finishPart();
    }
  }

  Future<void> _finishPart() async {
    await SpacedRepetitionService.markPartCompleted(widget.day, widget.part);
    SoundService.playFinish();

    if (mounted) {
      setState(() => _isPartFinished = true);
    }
  }

  void _continueFromFinished() {
    final partNum = DayProgress.sessionPartToNumber(widget.part);
    // Sonraki part var mı?
    final nextPart = DayProgress.numberToSessionPart(partNum + 1);

    if (nextPart == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionPage(day: widget.day, part: nextPart),
        ),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1128),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3A86FF)),
        ),
      );
    }

    if (_isPartFinished) return _buildPartFinishedView();

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1128),
        appBar: _buildAppBar(showProgress: false),
        body: const Center(
          child: Text(
            'Bu part için kelime bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: _buildAppBar(
        showProgress: true,
        progress: progress,
        part: q.part,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
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
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.06, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: _buildQuestionCard(q, key: ValueKey(_currentIndex)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Hata feedback paneli
            if (_showFeedback)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) => FractionalTranslation(
                    translation: offset,
                    child: child,
                  ),
                  child: _buildFeedbackPanel(q),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar({
    bool showProgress = true,
    double progress = 0,
    SessionPart? part,
  }) {
    final partNum = part != null ? DayProgress.sessionPartToNumber(part) : 1;
    final dayType = SpacedRepetitionService.getDayType(widget.day);
    final dayLabel = dayType == DayType.review ? '🔄 Tekrar' : '📘 Öğrenme';

    final partColors = {
      SessionPart.part1: const Color(0xFF3A86FF),
      SessionPart.part2: const Color(0xFF7209B7),
      SessionPart.part3: const Color(0xFF00E676),
      SessionPart.part4: const Color(0xFFFFB703),
    };
    final color = part != null
        ? (partColors[part] ?? const Color(0xFF3A86FF))
        : const Color(0xFF3A86FF);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: showProgress
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Part $partNum/4',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $dayLabel',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF1E2D4A),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ],
            )
          : null,
      actions: [
        if (showProgress)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Soru Kartı Yönlendirici ──────────────────────────────────────────────

  Widget _buildQuestionCard(ExerciseQuestion q, {required Key key}) {
    switch (q.type) {
      case ExerciseType.sentenceEnWithTr:
        return _buildSentenceEnWithTrCard(q, key: key);
      case ExerciseType.sentenceEnWithEn:
        return _buildSentenceEnWithEnCard(q, key: key);
      case ExerciseType.sentenceTrWithEn:
        return _buildSentenceTrWithEnCard(q, key: key);
      case ExerciseType.sentenceTrWithTr:
        return _buildSentenceTrWithTrCard(q, key: key);
    }
  }

  // ─── Ortak Cümle Widget'ı ─────────────────────────────────────────────────

  /// Cümleyi parantez içindeki kelimeyi vurgulayarak render eder.
  Widget _buildHighlightedSentence(String sentence, Color highlightColor) {
    // Parantez içindeki kısmı bul
    final regex = RegExp(r'\(([^)]+)\)');
    final match = regex.firstMatch(sentence);
    if (match == null) {
      return Text(
        sentence,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      );
    }

    final before = sentence.substring(0, match.start);
    final highlighted = match.group(1) ?? '';
    final after = sentence.substring(match.end);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: '($highlighted)',
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  // ─── Tip 1: EN cümle + (Türkçe) → EN cevap ───────────────────────────────

  Widget _buildSentenceEnWithTrCard(ExerciseQuestion q, {Key? key}) {
    // Cümle: "The doctor cared for the (hasta)." veya "She is very (sabırlı) with her children."
    // Parantez içinde bu cümleyle eşleşen Türkçe anlam olacak
    String sentence = q.sentenceEn ?? '';
    if (sentence.isNotEmpty) {
      sentence = sentence.replaceAll(
        RegExp(r'\([^)]+\)'),
        '(${q.matchedTrMeaning})',
      );
    }

    return _buildSentenceCard(
      key: key,
      instruction: 'İngilizcesini yazın',
      sentence: sentence.isNotEmpty ? sentence : null,
      fallbackWidget: sentence.isEmpty
          ? _buildFallbackTrToEn(q)
          : null,
      highlightColor: const Color(0xFFFFB703),
      isCorrect: _correctStroke,
      isWrong: _wrongStroke,
    );
  }

  // ─── Tip 2: EN cümle + (İngilizce) → TR cevap ───────────────────────────

  Widget _buildSentenceEnWithEnCard(ExerciseQuestion q, {Key? key}) {
    // Cümle: "The doctor cared for the (patient)."
    // Parantez içinde İngilizce kelime
    String sentence = q.sentenceEn ?? '';
    if (sentence.isNotEmpty) {
      sentence = sentence.replaceAll(
        RegExp(r'\([^)]+\)'),
        '(${q.wordEn})',
      );
    }

    return _buildSentenceCard(
      key: key,
      instruction: 'Türkçe anlamını yazın',
      sentence: sentence.isNotEmpty ? sentence : null,
      fallbackWidget: sentence.isEmpty
          ? _buildFallbackEnToTr(q)
          : null,
      highlightColor: const Color(0xFF3A86FF),
      isCorrect: _correctStroke,
      isWrong: _wrongStroke,
      hintText: 'Türkçe anlamını yazın...',
    );
  }

  // ─── Tip 3: TR cümle + (İngilizce) → TR cevap ───────────────────────────

  Widget _buildSentenceTrWithEnCard(ExerciseQuestion q, {Key? key}) {
    // Cümle: "Doktor (patient) ile yakından ilgilendi."
    String sentence = q.sentenceTr ?? '';
    if (sentence.isNotEmpty) {
      sentence = sentence.replaceAll(
        RegExp(r'\([^)]+\)'),
        '(${q.wordEn})',
      );
    }

    return _buildSentenceCard(
      key: key,
      instruction: 'Türkçe anlamını yazın',
      sentence: sentence.isNotEmpty ? sentence : null,
      fallbackWidget: sentence.isEmpty
          ? _buildFallbackEnToTr(q)
          : null,
      highlightColor: const Color(0xFF3A86FF),
      isCorrect: _correctStroke,
      isWrong: _wrongStroke,
      hintText: 'Türkçe anlamını yazın...',
    );
  }

  // ─── Tip 4: TR cümle + (Türkçe) → EN cevap ──────────────────────────────

  Widget _buildSentenceTrWithTrCard(ExerciseQuestion q, {Key? key}) {
    // Cümle: "Doktor (hasta) ile yakından ilgilendi." veya "Çocuklarına karşı çok (sabırlı) davranır."
    // Parantez içinde bu cümleyle eşleşen Türkçe anlam
    String sentence = q.sentenceTr ?? '';
    if (sentence.isNotEmpty) {
      sentence = sentence.replaceAll(
        RegExp(r'\([^)]+\)'),
        '(${q.matchedTrMeaning})',
      );
    }

    return _buildSentenceCard(
      key: key,
      instruction: 'İngilizcesini yazın',
      sentence: sentence.isNotEmpty ? sentence : null,
      fallbackWidget: sentence.isEmpty
          ? _buildFallbackTrToEn(q)
          : null,
      highlightColor: const Color(0xFFFFB703),
      isCorrect: _correctStroke,
      isWrong: _wrongStroke,
    );
  }

  // ─── Ortak Cümle Kart Yapısı ──────────────────────────────────────────────

  Widget _buildSentenceCard({
    Key? key,
    required String instruction,
    String? sentence,
    Widget? fallbackWidget,
    required Color highlightColor,
    bool isCorrect = false,
    bool isWrong = false,
    String hintText = 'İngilizcesini yazın...',
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(isCorrect: isCorrect, isWrong: isWrong),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            instruction,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),

          if (sentence != null)
            _buildHighlightedSentence(sentence, highlightColor)
          else
            ?fallbackWidget,

          const SizedBox(height: 32),
          _buildWritingField(hintText: hintText),
        ],
      ),
    );
  }

  // ─── Fallback Widget'ları (cümle yoksa) ──────────────────────────────────

  /// Cümle yoksa: sadece Türkçe kelimeyi göster, İngilizce iste
  Widget _buildFallbackTrToEn(ExerciseQuestion q) {
    return Text(
      q.wordTr,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFFFB703),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Cümle yoksa: sadece İngilizce kelimeyi göster, Türkçe iste
  Widget _buildFallbackEnToTr(ExerciseQuestion q) {
    return Text(
      q.wordEn,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF3A86FF),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ─── Yazma Alanı (Ortak) ─────────────────────────────────────────────────

  Widget _buildWritingField({String hintText = 'İngilizcesini yazın...'}) {
    return Column(
      children: [
        TextField(
          key: ValueKey('input_field_$_currentIndex'),
          controller: _textController,
          focusNode: _focusNode,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                const TextStyle(color: Colors.white30, fontSize: 17, letterSpacing: 0),
            filled: true,
            fillColor: const Color(0xFF0A1128),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF3A86FF), width: 2),
            ),
          ),
          onSubmitted: _checkAnswer,
          textInputAction: TextInputAction.done,
          enabled: !_isCorrect && !_showFeedback,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!_isCorrect && !_showFeedback)
                ? () => _checkAnswer(_textController.text)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A86FF),
              disabledBackgroundColor: const Color(0xFF1E2D4A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Kontrol Et',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Feedback Paneli ──────────────────────────────────────────────────────

  Widget _buildFeedbackPanel(ExerciseQuestion q) {
    final correctAnswer = q.direction == AnswerDirection.toEnglish
        ? q.wordEn
        : q.wordTr;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131D36),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yanlış Cevap',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedAnswer != null && _selectedAnswer!.isNotEmpty) ...[
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                              text: 'Senin cevabın: ',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                            TextSpan(
                              text: _selectedAnswer!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(
                                  text: 'Doğrusu: ',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 16),
                                ),
                                TextSpan(
                                  text: correctAnswer,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          // Hoparlör sadece feedback panelinde görünür
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded,
                                color: Colors.white60),
                            onPressed: () => TtsService.speak(
                                AnswerValidator.cleanForTts(q.wordEn)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // False friend notu
            if (_falseFriendNote != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _falseFriendNote!,
                        style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2D4A),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Anladım, Devam Et',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Part Bitti Ekranı ────────────────────────────────────────────────────

  Widget _buildPartFinishedView() {
    final partNum = DayProgress.sessionPartToNumber(widget.part);
    final nextPart = DayProgress.numberToSessionPart(partNum + 1);
    final bool hasNextPart = nextPart != null;

    final partColors = {
      SessionPart.part1: const Color(0xFF3A86FF),
      SessionPart.part2: const Color(0xFF7209B7),
      SessionPart.part3: const Color(0xFF00E676),
      SessionPart.part4: const Color(0xFFFFB703),
    };
    final color = partColors[widget.part] ?? const Color(0xFF3A86FF);
    final accuracy = _totalAnswered > 0
        ? ((_correctCount / _totalAnswered) * 100).round()
        : 100;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Trophy
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: color, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasNextPart ? 'Part $partNum Bitti 🎉' : 'Gün Tamamlandı! 🏆',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _words.isEmpty
                        ? 'Bugün için kelime bulunamadı.'
                        : '${_words.length} kelime üzerinde çalışıldı',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                  const SizedBox(height: 28),

                  // İstatistik
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                              Icons.quiz_outlined,
                              '$_totalAnswered',
                              'Toplam Soru',
                              const Color(0xFF3A86FF))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              Icons.speed_rounded, '%$accuracy', 'Başarı', color)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              Icons.auto_stories_rounded,
                              '${_words.length}',
                              'Kelime',
                              const Color(0xFFFFB703))),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Günün kelimeleri listesi
                  if (_words.isNotEmpty) ...[
                    _sectionHeader('Kelimeler'),
                    const SizedBox(height: 12),
                    ..._words.map((w) => _wordListTile(w)),
                    const SizedBox(height: 24),
                  ],

                  // Devam butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continueFromFinished,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        hasNextPart ? 'Part ${partNum + 1}\'e Geç' : 'Ana Menüye Dön',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (hasNextPart) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Color(0xFF1E2D4A)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Ana Menüye Dön',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Yardımcı Widget'lar ──────────────────────────────────────────────────

  BoxDecoration _cardDecoration({bool isCorrect = false, bool isWrong = false}) {
    Color borderColor = const Color(0xFF1E2D4A);
    if (isCorrect) borderColor = const Color(0xFF4CAF50);
    if (isWrong) borderColor = Colors.redAccent;

    return BoxDecoration(
      color: const Color(0xFF131D36),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: borderColor, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        if (isCorrect)
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        if (isWrong)
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _wordListTile(SpacedWord w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1729),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(w.wordEn,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(w.wordTr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF3A86FF), fontSize: 14)),
                    ),
                  ],
                ),
                if ((w.exampleSentence ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (w.exampleSentence ?? '').split('/').first.trim(),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded,
                color: Color(0xFF3A86FF), size: 20),
            onPressed: () =>
                TtsService.speak(AnswerValidator.cleanForTts(w.wordEn)),
          ),
        ],
      ),
    );
  }
}

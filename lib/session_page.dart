import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'spaced_repetition_service.dart';
import 'models/exercise_types.dart';
import 'utils/sound_service.dart';
import 'utils/tts_service.dart';
import 'utils/answer_validator.dart';

// ─── Session Question Builder ──────────────────────────────────────────────

List<ExerciseQuestion> buildPart1Questions(List<SpacedWord> words) {
  final List<ExerciseQuestion> qs = [];
  // 1a) Flashcard tanıtım
  for (final w in words) {
    qs.add(_makeQuestion(w, ExerciseType.flashcard, SessionPart.introduction));
  }
  // 1b) TR→EN yazma
  final shuffled = List<SpacedWord>.from(words)..shuffle();
  for (final w in shuffled) {
    qs.add(_makeQuestion(w, ExerciseType.trToEnWriting, SessionPart.introduction));
  }
  return qs;
}

List<ExerciseQuestion> buildPart2Questions(List<SpacedWord> words) {
  final List<ExerciseQuestion> qs = [];
  final s1 = List<SpacedWord>.from(words)..shuffle();
  for (final w in s1) {
    qs.add(_makeQuestion(w, ExerciseType.enToTrWriting, SessionPart.deepening));
  }
  final s2 = List<SpacedWord>.from(words)..shuffle();
  for (final w in s2) {
    // Cümle yoksa TR→EN fallback
    final hasSentence = (w.exampleSentence ?? '').isNotEmpty &&
        (w.exampleSentence ?? '').contains('_____');
    final type = hasSentence ? ExerciseType.clozeWriting : ExerciseType.trToEnWriting;
    qs.add(_makeQuestion(w, type, SessionPart.deepening));
  }
  return qs;
}

List<ExerciseQuestion> buildPart3Questions(List<SpacedWord> words) {
  return words.map((w) {
    final type = SpacedRepetitionService.getExerciseTypeForStep(w.step);
    return _makeQuestion(w, type, SessionPart.review);
  }).toList();
}

List<ExerciseQuestion> buildBonusQuestions(List<SpacedWord> words) {
  return words.map((w) =>
      _makeQuestion(w, ExerciseType.trToEnWriting, SessionPart.bonus)).toList();
}

String _pickSingleSentence(String text) {
  if (!text.contains('/')) return text.trim();
  final parts =
      text.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return text.trim();
  return parts[Random().nextInt(parts.length)];
}

ExerciseQuestion _makeQuestion(
    SpacedWord w, ExerciseType type, SessionPart part) {
  String sentenceEn = (w.exampleSentence ?? '').trim();
  String sentenceTr = (w.exampleTr ?? '').trim();

  // Çoklu cümle varsa ("/" ile ayrılmış), TR ve EN uyumlu olacak şekilde rastgele birini seç
  if (sentenceEn.contains('/') && sentenceTr.contains('/')) {
    final enParts = sentenceEn
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final trParts = sentenceTr
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (enParts.isNotEmpty && enParts.length == trParts.length) {
      final index = Random().nextInt(enParts.length);
      sentenceEn = enParts[index];
      sentenceTr = trParts[index];
    } else if (enParts.isNotEmpty) {
      final index = Random().nextInt(enParts.length);
      sentenceEn = enParts[index];
      if (trParts.isNotEmpty) {
        sentenceTr = trParts[min(index, trParts.length - 1)];
      }
    }
  } else if (sentenceEn.contains('/')) {
    sentenceEn = _pickSingleSentence(sentenceEn);
  } else if (sentenceTr.contains('/')) {
    sentenceTr = _pickSingleSentence(sentenceTr);
  }

  // Boşluk işareti normalizasyonu
  if (sentenceEn.isNotEmpty && !sentenceEn.contains('_____')) {
    sentenceEn = sentenceEn.replaceAll(
        RegExp(RegExp.escape(w.wordEn), caseSensitive: false), '_____');
  }

  return ExerciseQuestion(
    type: type,
    part: part,
    wordId: w.id,
    wordEn: w.wordEn,
    wordTr: w.wordTr,
    sentenceEn: sentenceEn.isEmpty ? null : sentenceEn,
    sentenceTr: sentenceTr.isEmpty ? null : sentenceTr,
    step: w.step,
  );
}

// ─── SessionPage ───────────────────────────────────────────────────────────

class SessionPage extends StatefulWidget {
  final int day;
  final SessionPart part;

  const SessionPage({
    super.key,
    this.day = 1,
    this.part = SessionPart.introduction,
  });

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage>
    with TickerProviderStateMixin {
  List<ExerciseQuestion> _questions = [];
  List<SpacedWord> _newWords = [];
  bool _isLoading = true;
  bool _isPartFinished = false;

  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalAnswered = 0;

  bool _showFeedback = false;
  bool _isCorrect = false;
  String? _selectedAnswer;
  String? _falseFriendNote;

  // Seans içinde yanlış bilinen kelimeler (bonus için)
  final Map<String, int> _wrongCountMap = {};
  bool _noReviewForPart3 = false;

  final TextEditingController _textController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  late AnimationController _shakeController;
  late AnimationController _correctController;

  double get _correctProgress =>
      _correctController.isAnimating ? sin(_correctController.value * pi).clamp(0.0, 1.0) : 0.0;

  // Dinleme modunda kelimeyi kaç kez dinledi
  int _listenCount = 0;
  static const int _maxListenCount = 3;

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
    _correctController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _loadPartQuestions();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _textController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _correctController.dispose();
    super.dispose();
  }

  void _continueFromFinished() {
    final bool hasNextPart = !(widget.part == SessionPart.review ||
        widget.part == SessionPart.bonus ||
        _noReviewForPart3);

    if (!hasNextPart) {
      Navigator.of(context).pop();
    } else {
      final nextPart = widget.part == SessionPart.introduction
          ? SessionPart.deepening
          : SessionPart.review;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionPage(day: widget.day, part: nextPart),
        ),
      );
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    // ESC: Eğitimden çık / Ana menüye dön
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }

    // ENTER: Devam et (Yanlış bildirim paneli, bitiş ekranı, flashcard)
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

      if (!_isLoading && _questions.isNotEmpty) {
        final currentQ = _questions[_currentIndex];
        if (currentQ.type == ExerciseType.flashcard) {
          _onFlashcardNext();
          return true;
        }
      }
    }

    return false;
  }

  // ─── Yükleme ────────────────────────────────────────────────────────────

  Future<void> _loadPartQuestions() async {
    try {
      await SpacedRepetitionService.setCurrentPart(widget.day, widget.part);
      List<ExerciseQuestion> questions = [];

      switch (widget.part) {
        case SessionPart.introduction:
          final words =
              await SpacedRepetitionService.getNewWordsForDay(widget.day);
          _newWords = words;
          questions = buildPart1Questions(words);
          break;

        case SessionPart.deepening:
          final words =
              await SpacedRepetitionService.getNewWordsForDay(widget.day);
          _newWords = words;
          questions = buildPart2Questions(words);
          break;

        case SessionPart.review:
          final words =
              await SpacedRepetitionService.getReviewWordsForDay(widget.day);
          _newWords = words;
          if (words.isEmpty) {
            await SpacedRepetitionService.markPartCompleted(
              widget.day,
              SessionPart.review,
              reviewCount: 0,
            );
            if (mounted) {
              setState(() {
                _questions = [];
                _isLoading = false;
                _isPartFinished = true;
              });
            }
            return;
          }
          questions = buildPart3Questions(words);
          break;

        case SessionPart.bonus:
          // Bonus: yanlış bilinen kelimeler ana sayfadan SpacedWord olarak gelemez,
          // review listesinden yanlış olanları al.
          final all =
              await SpacedRepetitionService.getReviewWordsForDay(widget.day);
          final newW =
              await SpacedRepetitionService.getNewWordsForDay(widget.day);
          final allWords = [...all, ...newW];
          // day_progress'teki wrong_words_in_session listesi ile filtrele
          final progress = await SpacedRepetitionService.getDayPartProgress(
              widget.day);
          final wrongIds = progress.wrongWordsInSession.toSet();
          final wrongWords =
              allWords.where((w) => wrongIds.contains(w.id)).toList();
          _newWords = wrongWords;
          questions = buildBonusQuestions(wrongWords);
          break;
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        // İlk soruyu seslendir
        if (_questions.isNotEmpty) {
          _speakCurrentQuestion(_questions[0]);
          if (_questions[0].type != ExerciseType.flashcard) {
            _focusWritingInput();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading part questions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── TTS ─────────────────────────────────────────────────────────────────

  void _speakCurrentQuestion(ExerciseQuestion q) {
    switch (q.type) {
      case ExerciseType.flashcard:
        // Flashcard: otomatik TTS
        Future.delayed(const Duration(milliseconds: 300), () {
          TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));
        });
        break;
      case ExerciseType.enToTrWriting:
        // EN→TR: kelimeyi söyle
        Future.delayed(const Duration(milliseconds: 200), () {
          TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));
        });
        break;
      case ExerciseType.listeningWriting:
        // Dinleme modu: sadece ses
        _listenCount = 1;
        Future.delayed(const Duration(milliseconds: 400), () {
          TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));
        });
        break;
      default:
        // TR→EN, cloze, hinted: TTS otomatik çalışmaz
        break;
    }
  }

  // ─── Cevap Kontrolü ───────────────────────────────────────────────────────

  void _checkAnswer(String rawAnswer) {
    if (_showFeedback || _isCorrect || _questions.isEmpty) return;
    final answer = rawAnswer.trim();
    if (answer.isEmpty) return;

    final q = _questions[_currentIndex];
    bool isCorrect;

    switch (q.type) {
      case ExerciseType.trToEnWriting:
      case ExerciseType.clozeWriting:
      case ExerciseType.hintedWriting:
      case ExerciseType.listeningWriting:
        isCorrect = AnswerValidator.isEnglishCorrect(answer, q.wordEn);
        break;
      case ExerciseType.enToTrWriting:
        isCorrect = AnswerValidator.isTurkishCorrect(answer, q.wordTr);
        break;
      case ExerciseType.flashcard:
        isCorrect = true; // Flashcard'da cevap yok
        break;
    }

    _totalAnswered++;

    // SRS güncelle (flashcard hariç)
    if (q.type != ExerciseType.flashcard) {
      SpacedRepetitionService.updateWordProgress(
        q.wordId,
        isCorrect,
        activeDay: widget.day,
      );
    }

    if (isCorrect) {
      _correctCount++;
      SoundService.playCorrect();
      // TR→EN, cloze, hinted, listening: doğruysa İngilizce'yi seslendir
      if (q.type != ExerciseType.enToTrWriting) {
        TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));
      }
      setState(() {
        _isCorrect = true;
        _selectedAnswer = answer;
      });
      _correctController.forward(from: 0.0);
      Future.delayed(const Duration(milliseconds: 550), _nextQuestion);
    } else {
      SoundService.playWrong();
      _shakeController.forward(from: 0.0);

      // Yanlış sayacı
      _wrongCountMap[q.wordId] = (_wrongCountMap[q.wordId] ?? 0) + 1;

      // Yanlış bilinen soruyu sona ekle
      _questions.add(_makeQuestion(
        SpacedWord(
          id: q.wordId,
          wordEn: q.wordEn,
          wordTr: q.wordTr,
          exampleSentence: q.sentenceEn,
          exampleTr: q.sentenceTr,
          nextReviewDate: DateTime.now(),
          step: q.step,
          isLearning: true,
          assignedDay: widget.day,
          dueDay: widget.day,
        ),
        q.type,
        q.part,
      ));

      // False friend notu
      String? note;
      final enteredMeaning =
          SpacedRepetitionService.getWordMeaning(answer.toLowerCase());
      if (enteredMeaning != null && enteredMeaning.isNotEmpty) {
        note = "'$answer' → $enteredMeaning anlamına gelir.";
      }

      // Yanlış cevap feedback'inde kelimeyi söyle
      TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));

      setState(() {
        _isCorrect = false;
        _showFeedback = true;
        _selectedAnswer = answer;
        _falseFriendNote = note;
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
    Future.delayed(const Duration(milliseconds: 550), tryFocus);
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
        _selectedAnswer = null;
        _falseFriendNote = null;
        _textController.clear();
        _listenCount = 0;
      });
      _correctController.reset();

      final next = _questions[_currentIndex];
      _speakCurrentQuestion(next);

      if (next.type != ExerciseType.flashcard) {
        _focusWritingInput();
      }
    } else {
      _finishPart();
    }
  }

  Future<void> _finishPart() async {
    // Bonus tetikleme: seans boyunca 2+ kez yanlış bilinen kelimeler
    final wrongWordIds = _wrongCountMap.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList();

    if (wrongWordIds.isNotEmpty) {
      await SpacedRepetitionService.updateWrongWordsInSession(
          widget.day, wrongWordIds);
    }

    await SpacedRepetitionService.markPartCompleted(
      widget.day,
      widget.part,
      reviewCount: widget.part == SessionPart.review ? _newWords.length : null,
    );

    bool skipPart3 = false;
    if (widget.part == SessionPart.deepening) {
      final reviewWords =
          await SpacedRepetitionService.getReviewWordsForDay(widget.day);
      if (reviewWords.isEmpty) {
        await SpacedRepetitionService.markPartCompleted(
          widget.day,
          SessionPart.review,
          reviewCount: 0,
        );
        skipPart3 = true;
      }
    }

    SoundService.playFinish();

    if (mounted) {
      setState(() {
        _noReviewForPart3 = skipPart3;
        _isPartFinished = true;
      });
    }
  }

  // ─── Flashcard Aksiyonu ───────────────────────────────────────────────────

  void _onFlashcardNext() {
    _nextQuestion();
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
                          child: _buildQuestionCard(q,
                              key: ValueKey(_currentIndex)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Hata geri bildirim paneli
            if (_showFeedback)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<Offset>(
                  tween:
                      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
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
    final partLabels = {
      SessionPart.introduction: 'Part 1 • Tanıtım',
      SessionPart.deepening: 'Part 2 • Derinleştirme',
      SessionPart.review: 'Part 3 • Tekrar',
      SessionPart.bonus: 'Bonus • Zor Kelimeler',
    };
    final partColors = {
      SessionPart.introduction: const Color(0xFF3A86FF),
      SessionPart.deepening: const Color(0xFF7209B7),
      SessionPart.review: const Color(0xFF00E676),
      SessionPart.bonus: const Color(0xFFFFB703),
    };

    final label = part != null ? (partLabels[part] ?? '') : '';
    final color =
        part != null ? (partColors[part] ?? const Color(0xFF3A86FF)) : const Color(0xFF3A86FF);

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
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
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
    return AnimatedBuilder(
      key: key,
      animation: _correctController,
      builder: (context, _) {
        switch (q.type) {
          case ExerciseType.flashcard:
            return _buildFlashcardCard(q);
          case ExerciseType.trToEnWriting:
            return _buildTrToEnCard(q);
          case ExerciseType.enToTrWriting:
            return _buildEnToTrCard(q);
          case ExerciseType.clozeWriting:
            return _buildClozeCard(q);
          case ExerciseType.listeningWriting:
            return _buildListeningCard(q);
          case ExerciseType.hintedWriting:
            return _buildHintedCard(q);
        }
      },
    );
  }

  // ─── Flashcard ────────────────────────────────────────────────────────────

  Widget _buildFlashcardCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İngilizce kelime + TTS butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  q.wordEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ttsButton(q.wordEn),
            ],
          ),
          const SizedBox(height: 12),

          // Türkçe anlam
          Text(
            q.wordTr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3A86FF),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Örnek cümle (varsa)
          if ((q.sentenceTr ?? '').isNotEmpty || (q.sentenceEn ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1128),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFF1E2D4A), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((q.sentenceTr ?? '').isNotEmpty)
                    Text(
                      q.sentenceTr!,
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.4),
                    ),
                  if ((q.sentenceTr ?? '').isNotEmpty &&
                      (q.sentenceEn ?? '').isNotEmpty)
                    const SizedBox(height: 6),
                  if ((q.sentenceEn ?? '').isNotEmpty)
                    Text(
                      // Boşluğu doldurulmuş halde göster
                      (q.sentenceEn ?? '').replaceAll('_____', q.wordEn),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 32),

          // Öğrendim butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onFlashcardNext,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: const Text(
                'Öğrendim, Devam',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TR → EN Yazma ────────────────────────────────────────────────────────

  Widget _buildTrToEnCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(progress: _correctProgress),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'İngilizcesini yazın',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            q.wordTr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3A86FF),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          _buildWritingField(),
        ],
      ),
    );
  }

  // ─── EN → TR Yazma ────────────────────────────────────────────────────────

  Widget _buildEnToTrCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(progress: _correctProgress),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Türkçe anlamını yazın',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  q.wordEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ttsButton(q.wordEn),
            ],
          ),
          const SizedBox(height: 32),
          _buildWritingField(hintText: 'Türkçe anlamını yazın...'),
        ],
      ),
    );
  }

  // ─── Cümle Boşluk (Yazma) ────────────────────────────────────────────────

  Widget _buildClozeCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(progress: _correctProgress),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Boşluğu doldurun',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Türkçe cümle ipucu
          if ((q.sentenceTr ?? '').isNotEmpty)
            Text(
              q.sentenceTr!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 12),

          // İngilizce cümle boşluklu
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  q.sentenceEn ?? '_____',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
              _ttsButton(
                (q.sentenceEn ?? '_____')
                    .replaceAll('_____', q.wordEn),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildWritingField(),
        ],
      ),
    );
  }

  // ─── Dinleme → Yazma ─────────────────────────────────────────────────────

  Widget _buildListeningCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(32),
      decoration: _cardDecoration(progress: _correctProgress),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Büyük hoparlör ikonu
          GestureDetector(
            onTap: _listenCount < _maxListenCount
                ? () {
                    setState(() => _listenCount++);
                    TtsService.speak(AnswerValidator.cleanForTts(q.wordEn));
                  }
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3A86FF).withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.volume_up_rounded,
                color: _listenCount < _maxListenCount
                    ? const Color(0xFF3A86FF)
                    : Colors.white24,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _listenCount < _maxListenCount
                ? 'Tekrar dinlemek için dokun (${_maxListenCount - _listenCount} kez)'
                : 'Maksimum dinleme sayısına ulaştın',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Duyduğun İngilizce kelimeyi yaz',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          _buildWritingField(),
        ],
      ),
    );
  }

  // ─── İpuçlu Yazma ────────────────────────────────────────────────────────

  Widget _buildHintedCard(ExerciseQuestion q, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(progress: _correctProgress),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'İngilizcesini yazın',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            q.wordTr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3A86FF),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // İlk harf ipucu
          Text(
            q.hintText,
            style: const TextStyle(
              color: Color(0xFF00B4D8),
              fontSize: 26,
              letterSpacing: 5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          _buildWritingField(),
        ],
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
            onPressed:
                (!_isCorrect && !_showFeedback)
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
                  child:
                      const Icon(Icons.close_rounded, color: Colors.redAccent),
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
                                  text: q.type == ExerciseType.enToTrWriting
                                      ? q.wordTr
                                      : q.wordEn,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ]),
                            ),
                          ),
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
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3)),
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
    final partLabels = {
      SessionPart.introduction: 'Part 1 Tamamlandı! 🎉',
      SessionPart.deepening: 'Part 2 Tamamlandı!',
      SessionPart.review: 'Part 3 Tamamlandı! ⭐',
      SessionPart.bonus: 'Bonus Tamamlandı! 🏆',
    };
    final partColors = {
      SessionPart.introduction: const Color(0xFF3A86FF),
      SessionPart.deepening: const Color(0xFF7209B7),
      SessionPart.review: const Color(0xFF00E676),
      SessionPart.bonus: const Color(0xFFFFB703),
    };
    final bool hasNextPart = !(widget.part == SessionPart.review ||
        widget.part == SessionPart.bonus ||
        _noReviewForPart3);

    final nextPartLabels = {
      SessionPart.introduction: 'Part 2\'ye Geç',
      SessionPart.deepening: _noReviewForPart3 ? 'Ana Menüye Dön' : 'Part 3\'e Geç',
      SessionPart.review: 'Ana Menüye Dön',
      SessionPart.bonus: 'Ana Menüye Dön',
    };

    final title = partLabels[widget.part] ?? 'Tamamlandı!';
    final color = partColors[widget.part] ?? const Color(0xFF3A86FF);
    final nextLabel = nextPartLabels[widget.part] ?? 'Ana Menüye Dön';
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
                    child: Icon(Icons.emoji_events_rounded,
                        color: color, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _newWords.isEmpty
                        ? 'Bugün için tekrar edilecek kelime bulunmuyor.'
                        : '${_newWords.length} kelime üzerinde çalışıldı',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                  if (_noReviewForPart3) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF00E676), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Bugün tekrar kelimesi olmadığı için Part 3 tamamlandı.',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          child: _statCard(Icons.speed_rounded,
                              '%$accuracy', 'Başarı', color)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              Icons.auto_stories_rounded,
                              '${_newWords.length}',
                              'Kelime',
                              const Color(0xFFFFB703))),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Günün kelimeleri listesi
                  if (_newWords.isNotEmpty) ...[
                    _sectionHeader('Kelimeler'),
                    const SizedBox(height: 12),
                    ..._newWords.map((w) => _wordListTile(w)),
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
                        nextLabel,
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
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
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

  BoxDecoration _cardDecoration({double progress = 0.0}) {
    final hasProgress = progress > 0.005;
    final strokeColor = Color.lerp(
      const Color(0xFF1E2D4A),
      const Color(0xFF4CAF50).withValues(alpha: 0.65),
      progress,
    )!;
    final bgColor = Color.lerp(
      const Color(0xFF131D36),
      const Color(0xFF4CAF50).withValues(alpha: 0.06),
      progress,
    )!;

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: strokeColor,
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        if (hasProgress)
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.18 * progress),
            blurRadius: 16,
            spreadRadius: 1,
          ),
      ],
    );
  }


  Widget _ttsButton(String text) {
    return GestureDetector(
      onTap: () => TtsService.speak(AnswerValidator.cleanForTts(text)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_up_rounded,
            color: Color(0xFF3A86FF), size: 22),
      ),
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
                      _pickSingleSentence(w.exampleSentence!)
                          .replaceAll('_____', w.wordEn),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math' as math;
import 'models/exercise_types.dart';

class SpacedWord {
  final String id;
  final String wordEn;
  final String wordTr;
  final String? exampleSentence;
  final String? exampleTr;
  final DateTime nextReviewDate;
  final int step;
  final bool isLearning;
  final int assignedDay;
  final int dueDay;
  final int wrongCount;
  final bool mastered;

  SpacedWord({
    required this.id,
    required this.wordEn,
    required this.wordTr,
    this.exampleSentence,
    this.exampleTr,
    required this.nextReviewDate,
    required this.step,
    required this.isLearning,
    this.assignedDay = 1,
    this.dueDay = 1,
    this.wrongCount = 0,
    this.mastered = false,
  });

  factory SpacedWord.fromMap(String id, Map<String, dynamic> data) {
    return SpacedWord(
      id: id,
      wordEn: data['word_en'] ?? '',
      wordTr: data['word_tr'] ?? '',
      exampleSentence: data['example_sentence'],
      exampleTr: data['example_tr'],
      nextReviewDate: (data['next_review_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      step: data['step'] ?? 0,
      isLearning: data['is_learning'] ?? true,
      assignedDay: data['assigned_day'] ?? 1,
      dueDay: data['due_day'] ?? 1,
      wrongCount: data['wrong_count'] ?? 0,
      mastered: data['mastered'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word_en': wordEn,
      'word_tr': wordTr,
      'example_sentence': exampleSentence,
      'example_tr': exampleTr,
      'next_review_date': Timestamp.fromDate(nextReviewDate),
      'step': step,
      'is_learning': isLearning,
      'assigned_day': assignedDay,
      'due_day': dueDay,
      'wrong_count': wrongCount,
      'mastered': mastered,
    };
  }
}

/// Günlük seans ilerleme durumu (basitleştirilmiş).
class DayProgress {
  final int totalParts;
  final int completedParts;
  final DayType dayType;
  final int correctCount;
  final int totalAnswered;

  const DayProgress({
    this.totalParts = 4,
    this.completedParts = 0,
    this.dayType = DayType.learning,
    this.correctCount = 0,
    this.totalAnswered = 0,
  });

  bool get isCompleted => completedParts >= totalParts;

  bool isPartCompleted(SessionPart part) {
    final partNum = sessionPartToNumber(part);
    return completedParts >= partNum;
  }

  SessionPart? get nextPart {
    if (completedParts >= totalParts) return null;
    return numberToSessionPart(completedParts + 1);
  }

  DayProgress copyWith({
    int? totalParts,
    int? completedParts,
    DayType? dayType,
    int? correctCount,
    int? totalAnswered,
  }) {
    return DayProgress(
      totalParts: totalParts ?? this.totalParts,
      completedParts: completedParts ?? this.completedParts,
      dayType: dayType ?? this.dayType,
      correctCount: correctCount ?? this.correctCount,
      totalAnswered: totalAnswered ?? this.totalAnswered,
    );
  }

  factory DayProgress.fromMap(Map<String, dynamic> data) {
    return DayProgress(
      totalParts: (data['total_parts'] as num?)?.toInt() ?? 4,
      completedParts: (data['completed_parts'] as num?)?.toInt() ?? 0,
      dayType: data['day_type'] == 'review' ? DayType.review : DayType.learning,
      correctCount: (data['correct_count'] as num?)?.toInt() ?? 0,
      totalAnswered: (data['total_answered'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_parts': totalParts,
      'completed_parts': completedParts,
      'day_type': dayType == DayType.review ? 'review' : 'learning',
      'correct_count': correctCount,
      'total_answered': totalAnswered,
    };
  }

  static int sessionPartToNumber(SessionPart part) {
    switch (part) {
      case SessionPart.part1: return 1;
      case SessionPart.part2: return 2;
      case SessionPart.part3: return 3;
      case SessionPart.part4: return 4;
    }
  }

  static SessionPart? numberToSessionPart(int n) {
    switch (n) {
      case 1: return SessionPart.part1;
      case 2: return SessionPart.part2;
      case 3: return SessionPart.part3;
      case 4: return SessionPart.part4;
      default: return null;
    }
  }
}

class SpacedRepetitionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>>? _userWordsCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('words');
  }

  static int _cachedDay = 1;
  static final Map<int, DayProgress> _dayProgressCache = {};

  // ─── SRS Interval Tablosu ─────────────────────────────────────────────────
  static const List<int> _intervals = [
    0,   // Step 0: Yeni kelime, aynı gün
    1,   // Step 1: Ertesi gün
    2,   // Step 2: 2 gün sonra
    4,   // Step 3: 4 gün sonra
    7,   // Step 4: 1 hafta
    14,  // Step 5: 2 hafta
    30,  // Step 6: 1 ay
    60,  // Step 7: 2 ay
    120, // Step 8: 4 ay
    365, // Step 9: 1 yıl (ustalaşmış)
  ];

  // ─── Seans İçi Tekrar Sayısı (step'e göre) ───────────────────────────────
  /// Bir kelimenin bir seanste kaç kez tekrar edileceği (step'e göre azalır).
  static int getRepeatCount(int step) {
    if (step == 0) return 8;
    if (step == 1) return 6;
    if (step == 2) return 5;
    if (step == 3) return 4;
    if (step == 4) return 3;
    if (step == 5) return 2;
    return 2; // step 6+
  }

  // ─── Dictionary Cache ─────────────────────────────────────────────────────
  static Map<String, String>? _dictionary;
  static List<String>? _allWordsList;

  static Future<void> loadDictionaryIfNeeded() async {
    if (_dictionary != null && _allWordsList != null) return;
    try {
      final fileText = await rootBundle.loadString('assets/en_tr_word_list.txt');
      final lines = const LineSplitter().convert(fileText);
      final dict = <String, String>{};
      final words = <String>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(' - ');
        if (parts.length >= 2) {
          final en = parts[0].trim().toLowerCase();
          final tr = parts[1].trim();
          if (en.isNotEmpty && !dict.containsKey(en)) {
            dict[en] = tr;
            words.add(en);
          }
        }
      }
      _dictionary = dict;
      _allWordsList = words;
    } catch (e) {
      debugPrint('Failed to load dictionary: $e');
    }
  }

  static String? getWordMeaning(String wordEn) {
    return _dictionary?[wordEn.toLowerCase().trim()];
  }

  // ─── Gün Tipi ─────────────────────────────────────────────────────────────

  /// Her 5. gün tekrar günüdür (Gün 5, 10, 15, 20...).
  static DayType getDayType(int day) {
    if (day % 5 == 0) return DayType.review;
    return DayType.learning;
  }

  // ─── Kullanıcı Profili ────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> getUserProfileStream() {
    final doc = _userDoc();
    if (doc == null) {
      return Stream.value({'current_day': _cachedDay, 'streak': 0});
    }

    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      final streak = (data['streak'] as num?)?.toInt() ?? 0;
      final dbDay = (data['current_day'] as num?)?.toInt() ??
          (data['currentDay'] as num?)?.toInt();
      if (dbDay != null) _cachedDay = dbDay;

      return {
        'current_day': _cachedDay,
        'currentDay': _cachedDay,
        'streak': streak,
      };
    });
  }

  static Future<void> recordStudyActivity() async {
    final doc = _userDoc();
    if (doc == null) return;

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final snap = await doc.get();
    final data = snap.data() ?? {};
    final lastDateStr = data['last_study_date'] as String?;
    int streak = (data['streak'] as num?)?.toInt() ?? 0;

    if (lastDateStr == null) {
      streak = 1;
    } else if (lastDateStr != todayStr) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        if (diff == 1) {
          streak += 1;
        } else if (diff > 1) {
          streak = 1;
        }
      } else {
        streak = 1;
      }
    }

    await doc.set({
      'streak': streak,
      'last_study_date': todayStr,
    }, SetOptions(merge: true));
  }

  // ─── Gün Yönetimi ─────────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> getUserDayStream() {
    final doc = _userDoc();
    if (doc == null) return Stream.value({'current_day': _cachedDay});
    return doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      final dbDay = (data?['current_day'] as num?)?.toInt() ??
          (data?['currentDay'] as num?)?.toInt();
      if (dbDay != null) _cachedDay = dbDay;
      return {'current_day': _cachedDay};
    });
  }

  static Stream<int> getUserDayIntStream() {
    return getUserDayStream().map((m) => (m['current_day'] as num?)?.toInt() ?? 1);
  }

  static Future<int> getCurrentDay() async {
    final doc = _userDoc();
    if (doc == null) return _cachedDay;
    try {
      final snap = await doc.get();
      final data = snap.data();
      final dbDay = (data?['current_day'] as num?)?.toInt() ??
          (data?['currentDay'] as num?)?.toInt();
      if (dbDay != null) _cachedDay = dbDay;
    } catch (e) {
      debugPrint('getCurrentDay error: $e');
    }
    return _cachedDay;
  }

  static Future<void> setCurrentDay(int day) async {
    final safeDay = math.max(1, day);
    _cachedDay = safeDay;
    final doc = _userDoc();
    if (doc != null) {
      try {
        await doc.set({
          'current_day': safeDay,
          'currentDay': safeDay,
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('setCurrentDay error: $e');
      }
    }
    await _ensureWordsForDay(safeDay);
  }

  // ─── Kelime Yükleme ────────────────────────────────────────────────────────

  /// Günlük 5 yeni kelime.
  static const int newWordsPerDay = 5;

  /// Tekrar günlerinde maksimum kelime sayısı.
  static const int maxReviewWordsPerDay = 20;

  static Future<void> initMockDataIfEmpty() async {
    await loadDictionaryIfNeeded();
    final currentDay = await getCurrentDay();
    await _ensureWordsForDay(currentDay);
  }

  static Future<void> _ensureWordsForDay(int day) async {
    // Tekrar günlerinde yeni kelime ekleme
    if (getDayType(day) == DayType.review) return;

    await loadDictionaryIfNeeded();
    final collection = _userWordsCollection();
    if (collection == null) return;

    final existingSnap =
        await collection.where('assigned_day', isEqualTo: day).get();
    if (existingSnap.docs.isNotEmpty) return;

    String fileText = '';
    try {
      fileText = await rootBundle.loadString('assets/en_tr_word_list.txt');
    } catch (e) {
      debugPrint('Failed to load word list asset: $e');
      return;
    }

    final List<String> lines = const LineSplitter().convert(fileText);
    // Tekrar günlerini atlayarak index hesapla
    // Her 5 günden 4'ü öğrenme günü, bu yüzden kaçıncı öğrenme günü olduğunu bul
    final learningDayIndex = _getLearningDayIndex(day);
    final startIndex = learningDayIndex * newWordsPerDay;
    if (startIndex >= lines.length) return;

    final batch = _firestore.batch();
    int added = 0;

    for (int i = startIndex; i < lines.length && added < newWordsPerDay; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      final parts = line.split(' - ');
      if (parts.length >= 2) {
        final wordEn = parts[0].trim();
        final wordTr = parts[1].trim();
        String exampleTr = '';
        String exampleEn = '';

        if (parts.length >= 4) {
          exampleTr = parts[2].trim();
          exampleEn = parts[3].trim();
          // Parantez içi metni kelime olarak koru (soru oluşturucuya lazım)
          // Örnek: "(public) buildings" → kelimeyi ayıklayabiliriz
        }

        final docRef = collection.doc(wordEn);
        batch.set(docRef, {
          'word_en': wordEn,
          'word_tr': wordTr,
          'example_sentence': exampleEn,
          'example_tr': exampleTr,
          'next_review_date': Timestamp.fromDate(DateTime.now()),
          'step': 0,
          'is_learning': true,
          'assigned_day': day,
          'due_day': day,
          'wrong_count': 0,
          'mastered': false,
        }, SetOptions(merge: true));
        added++;
      }
    }

    if (added > 0) await batch.commit();
  }

  /// [day] günün kaçıncı öğrenme günü olduğunu hesaplar (0-indexed).
  /// Tekrar günleri (5, 10, 15...) atlanır.
  static int _getLearningDayIndex(int day) {
    int learningIndex = 0;
    for (int d = 1; d < day; d++) {
      if (getDayType(d) == DayType.learning) learningIndex++;
    }
    return learningIndex;
  }

  // ─── Part Yönetimi ─────────────────────────────────────────────────────────

  static Future<DayProgress> getDayProgress(int day) async {
    if (_dayProgressCache.containsKey(day)) {
      return _dayProgressCache[day]!;
    }

    final dayType = getDayType(day);
    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        final snap = await userDocRef.get();
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final dayMap = data['day_progress']?['day_$day'];
          if (dayMap is Map) {
            final res = DayProgress.fromMap(Map<String, dynamic>.from(dayMap));
            _dayProgressCache[day] = res;
            return res;
          }
        }
      } catch (e) {
        debugPrint('getDayProgress error: $e');
      }
    }

    // Varsayılan: hiç tamamlanmamış
    final defaultProgress = DayProgress(
      totalParts: 4,
      completedParts: 0,
      dayType: dayType,
    );
    _dayProgressCache[day] = defaultProgress;
    return defaultProgress;
  }

  static Stream<DayProgress> getDayProgressStream(int day) {
    final dayType = getDayType(day);
    final userDocRef = _userDoc();
    if (userDocRef == null) {
      return Stream.value(_dayProgressCache[day] ?? DayProgress(dayType: dayType));
    }

    return userDocRef.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return _dayProgressCache[day] ?? DayProgress(dayType: dayType);
      }
      final data = snap.data()!;
      final dayMap = data['day_progress']?['day_$day'];
      if (dayMap is Map) {
        final res = DayProgress.fromMap(Map<String, dynamic>.from(dayMap));
        _dayProgressCache[day] = res;
        return res;
      }
      return _dayProgressCache[day] ?? DayProgress(dayType: dayType);
    }).handleError((error) {
      debugPrint('getDayProgressStream error: $error');
      return _dayProgressCache[day] ?? DayProgress(dayType: dayType);
    });
  }

  static Future<void> markPartCompleted(int day, SessionPart part) async {
    final partNum = DayProgress.sessionPartToNumber(part);
    final existing = _dayProgressCache[day] ?? DayProgress(dayType: getDayType(day));
    final updated = existing.copyWith(
      completedParts: math.max(existing.completedParts, partNum),
    );
    _dayProgressCache[day] = updated;

    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'current_day': day,
          'currentDay': day,
          'day_progress': {
            'day_$day': updated.toMap(),
          },
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('markPartCompleted error: $e');
      }
    }
  }

  static Future<void> resetDayProgress(int day) async {
    final dayType = getDayType(day);
    _dayProgressCache[day] = DayProgress(dayType: dayType);

    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'current_day': day,
          'currentDay': day,
          'day_progress': {
            'day_$day': DayProgress(dayType: dayType).toMap(),
          },
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('resetDayProgress error: $e');
      }
    }

    // Günün kelimelerini sıfırla
    final wordsCol = _userWordsCollection();
    if (wordsCol != null) {
      try {
        final assignedSnap =
            await wordsCol.where('assigned_day', isEqualTo: day).get();
        final batch = _firestore.batch();
        for (var doc in assignedSnap.docs) {
          batch.update(doc.reference, {
            'step': 0,
            'due_day': day,
            'is_learning': true,
            'wrong_count': 0,
            'mastered': false,
            'next_review_date': Timestamp.fromDate(DateTime.now()),
          });
        }
        await batch.commit();
      } catch (e) {
        debugPrint('resetDayProgress words error: $e');
      }
    }
  }

  // ─── Kelime Getirme ────────────────────────────────────────────────────────

  static Future<List<SpacedWord>> getWordsForDay(int day) async {
    await loadDictionaryIfNeeded();
    final dayType = getDayType(day);

    if (dayType == DayType.learning) {
      await _ensureWordsForDay(day);
      final collection = _userWordsCollection();
      if (collection == null) return [];
      final snap = await collection.where('assigned_day', isEqualTo: day).get();
      return snap.docs
          .map((doc) => SpacedWord.fromMap(doc.id, doc.data()))
          .take(newWordsPerDay)
          .toList();
    } else {
      // Tekrar günü: önceki günlerin due olan kelimeleri
      return getReviewWordsForDay(day);
    }
  }

  static Future<List<SpacedWord>> getReviewWordsForDay(int day) async {
    await loadDictionaryIfNeeded();
    final collection = _userWordsCollection();
    if (collection == null) return [];

    final snap = await collection.get();
    final List<SpacedWord> reviewWords = [];

    for (var doc in snap.docs) {
      final w = SpacedWord.fromMap(doc.id, doc.data());
      if (w.assignedDay < day && w.dueDay <= day) {
        reviewWords.add(w);
      }
    }

    reviewWords.sort((a, b) => a.step.compareTo(b.step));
    return reviewWords.take(maxReviewWordsPerDay).toList();
  }

  // ─── Soru Oluşturma ────────────────────────────────────────────────────────

  /// Belirli bir part için soru listesi oluşturur.
  /// Her kelime 2 kez görülür: 1 EN cevap + 1 TR cevap.
  static List<ExerciseQuestion> buildPartQuestions(
    List<SpacedWord> words,
    SessionPart part,
  ) {
    final random = math.Random();
    final List<ExerciseQuestion> questions = [];

    // EN cevap isteyen tipler: sentenceEnWithTr (Tip1), sentenceTrWithTr (Tip4)
    // TR cevap isteyen tipler: sentenceEnWithEn (Tip2), sentenceTrWithEn (Tip3)
    final enAnswerTypes = [ExerciseType.sentenceEnWithTr, ExerciseType.sentenceTrWithTr];
    final trAnswerTypes = [ExerciseType.sentenceEnWithEn, ExerciseType.sentenceTrWithEn];

    for (final word in words) {
      // Cümle yoksa fallback: her iki yön de mevcut tipleri kullanır ama
      // cümlesiz kelimeler için bir tip seçebiliriz (başka cümle tipini dene)
      final hasSentence = (word.exampleSentence ?? '').isNotEmpty &&
          (word.exampleTr ?? '').isNotEmpty;

      // EN cevap sorusu
      ExerciseType enType;
      if (hasSentence) {
        enType = enAnswerTypes[random.nextInt(enAnswerTypes.length)];
      } else {
        enType = ExerciseType.sentenceTrWithTr; // TR cümle yok ise EN cümle zorla
        // Eğer EN cümlesi de yoksa, tip1 ile zorlama (wordTr parantez içinde gösterilir)
        enType = ExerciseType.sentenceEnWithTr;
      }

      // TR cevap sorusu
      ExerciseType trType;
      if (hasSentence) {
        trType = trAnswerTypes[random.nextInt(trAnswerTypes.length)];
      } else {
        trType = ExerciseType.sentenceEnWithEn;
      }

      questions.add(_makeQuestion(word, enType, part));
      questions.add(_makeQuestion(word, trType, part));
    }

    // Karıştır, aynı kelime arka arkaya gelmesin
    _shuffleNoConsecutive(questions, random);
    return questions;
  }

  /// Tüm seans sorularını oluşturur (tek part için değil, tam gün için,
  /// part bazlı bölünmeden önce kullanılır).
  /// Her kelime getRepeatCount(step) kadar tekrar eder.
  static List<ExerciseQuestion> buildAllSessionQuestions(
    List<SpacedWord> words,
    SessionPart part,
  ) {
    final random = math.Random();
    final List<ExerciseQuestion> questions = [];

    final enAnswerTypes = [ExerciseType.sentenceEnWithTr, ExerciseType.sentenceTrWithTr];
    final trAnswerTypes = [ExerciseType.sentenceEnWithEn, ExerciseType.sentenceTrWithEn];

    for (final word in words) {
      final repeatCount = getRepeatCount(word.step);
      final halfCount = repeatCount ~/ 2;
      final enCount = halfCount;
      final trCount = repeatCount - halfCount; // remainder goes to TR

      final hasSentence = (word.exampleSentence ?? '').isNotEmpty &&
          (word.exampleTr ?? '').isNotEmpty;

      for (int i = 0; i < enCount; i++) {
        ExerciseType type;
        if (hasSentence) {
          type = enAnswerTypes[random.nextInt(enAnswerTypes.length)];
        } else {
          type = ExerciseType.sentenceEnWithTr;
        }
        questions.add(_makeQuestion(word, type, part));
      }

      for (int i = 0; i < trCount; i++) {
        ExerciseType type;
        if (hasSentence) {
          type = trAnswerTypes[random.nextInt(trAnswerTypes.length)];
        } else {
          type = ExerciseType.sentenceEnWithEn;
        }
        questions.add(_makeQuestion(word, type, part));
      }
    }

    _shuffleNoConsecutive(questions, random);
    return questions;
  }

  /// Yanlış bilinen soruyu tekrar kuyruğuna eklemek için yeni soru oluşturur.
  static ExerciseQuestion buildRetryQuestion(ExerciseQuestion q, SessionPart part) {
    return ExerciseQuestion(
      type: q.type,
      part: part,
      direction: q.direction,
      wordId: q.wordId,
      wordEn: q.wordEn,
      wordTr: q.wordTr,
      sentenceEn: q.sentenceEn,
      sentenceTr: q.sentenceTr,
      step: q.step,
    );
  }

  static ExerciseQuestion _makeQuestion(
      SpacedWord w, ExerciseType type, SessionPart part) {
    // EN ve TR cümlelerini aynı index ile seç (anlam-cümle eşleşmesi için)
    final picked = _pickPairedSentences(
      enText: w.exampleSentence ?? '',
      trText: w.exampleTr ?? '',
      trMeanings: w.wordTr,
    );
    String sentenceEn = picked.sentenceEn;
    String sentenceTr = picked.sentenceTr;
    final String matchedTrMeaning = picked.matchedTrMeaning;

    // EN cümle: kelime İngilizce haliyle parantez içinde olmalı
    if (sentenceEn.isNotEmpty && !sentenceEn.contains('(')) {
      sentenceEn = sentenceEn.replaceAll(
        RegExp(RegExp.escape(w.wordEn), caseSensitive: false),
        '(${w.wordEn})',
      );
    }
    // TR cümle: cümleyle eşleşen Türkçe anlam parantez içinde olmalı
    if (sentenceTr.isNotEmpty && !sentenceTr.contains('(')) {
      sentenceTr = sentenceTr.replaceAll(
        RegExp(RegExp.escape(matchedTrMeaning), caseSensitive: false),
        '($matchedTrMeaning)',
      );
    }

    final direction = (type == ExerciseType.sentenceEnWithTr ||
            type == ExerciseType.sentenceTrWithTr)
        ? AnswerDirection.toEnglish
        : AnswerDirection.toTurkish;

    // wordTr → validasyon için tüm anlamlar korunur (hasta / sabırlı gibi)
    // matchedTrMeaning → sadece cümle içi parantez görünümü için kullanıldı
    return ExerciseQuestion(
      type: type,
      part: part,
      direction: direction,
      wordId: w.id,
      wordEn: w.wordEn,
      wordTr: w.wordTr,
      sentenceEn: sentenceEn.isEmpty ? null : sentenceEn,
      sentenceTr: sentenceTr.isEmpty ? null : sentenceTr,
      step: w.step,
    );
  }

  /// EN cümle, TR cümle ve TR anlam listesini aynı index ile seçer.
  /// Kural: Cümle index = anlam index → her zaman tutarlı eşleşme.
  static ({String sentenceEn, String sentenceTr, String matchedTrMeaning})
      _pickPairedSentences({
    required String enText,
    required String trText,
    required String trMeanings,
  }) {
    final enParts = enText.isEmpty
        ? <String>[]
        : enText.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final trParts = trText.isEmpty
        ? <String>[]
        : trText.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final meanings = trMeanings
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (enParts.isEmpty && trParts.isEmpty) {
      return (
        sentenceEn: '',
        sentenceTr: '',
        matchedTrMeaning: meanings.isNotEmpty ? meanings.first : trMeanings,
      );
    }

    // Kaç seçenek var: EN ve TR'nin minimumuyla sınırla
    final maxIndex = (enParts.isNotEmpty && trParts.isNotEmpty)
        ? math.min(enParts.length, trParts.length) - 1
        : (enParts.isNotEmpty ? enParts.length - 1 : trParts.length - 1);

    final idx = maxIndex >= 0 ? math.Random().nextInt(maxIndex + 1) : 0;

    final selectedEn = enParts.isNotEmpty
        ? (idx < enParts.length ? enParts[idx] : enParts.first)
        : '';
    final selectedTr = trParts.isNotEmpty
        ? (idx < trParts.length ? trParts[idx] : trParts.first)
        : '';

    // Aynı index'teki TR anlamı; yoksa ilkini kullan
    final matchedMeaning =
        meanings.isNotEmpty ? (idx < meanings.length ? meanings[idx] : meanings.first) : trMeanings;

    return (
      sentenceEn: selectedEn,
      sentenceTr: selectedTr,
      matchedTrMeaning: matchedMeaning,
    );
  }

  /// Aynı kelime arka arkaya gelmeyecek şekilde karıştırır.
  static void _shuffleNoConsecutive(
      List<ExerciseQuestion> questions, math.Random random) {
    questions.shuffle(random);
    // Max 10 deneme
    for (int attempt = 0; attempt < 10; attempt++) {
      bool hasConsecutive = false;
      for (int i = 1; i < questions.length; i++) {
        if (questions[i].wordId == questions[i - 1].wordId) {
          hasConsecutive = true;
          // Sonraki farklı kelimeyi bul ve swap yap
          for (int j = i + 1; j < questions.length; j++) {
            if (questions[j].wordId != questions[i - 1].wordId) {
              final tmp = questions[i];
              questions[i] = questions[j];
              questions[j] = tmp;
              break;
            }
          }
          break;
        }
      }
      if (!hasConsecutive) break;
    }
  }

  // ─── İlerleme Güncelleme ─────────────────────────────────────────────────

  static Future<void> updateWordProgress(
    String wordId,
    bool isCorrect, {
    int? activeDay,
  }) async {
    final collection = _userWordsCollection();
    if (collection == null) return;

    final docRef = collection.doc(wordId);
    final day = activeDay ?? await getCurrentDay();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int step = data['step'] ?? 0;
      int wrongCount = data['wrong_count'] ?? 0;

      if (isCorrect) {
        if (step < _intervals.length - 1) step++;
      } else {
        step = (step > 2) ? step - 2 : 0;
        wrongCount++;
      }

      final intervalDays = _intervals[step];
      final nextDueDay = day + (isCorrect ? intervalDays : 1);
      final mastered = step >= 7;

      transaction.update(docRef, {
        'step': step,
        'due_day': nextDueDay,
        'next_review_date': Timestamp.fromDate(
          DateTime.now().add(Duration(days: intervalDays)),
        ),
        'is_learning': step <= 1,
        'wrong_count': wrongCount,
        'mastered': mastered,
        'last_reviewed_day': day,
      });
    });

    await recordStudyActivity();
  }

  // ─── İstatistikler ────────────────────────────────────────────────────────

  static Stream<Map<String, int>> getStatsStreamForDay(int activeDay) {
    final collection = _userWordsCollection();
    if (collection == null) {
      return Stream.value(
          {'new': 0, 'review': 0, 'total_learned': 0, 'total_words': 0});
    }

    return collection.snapshots().map((snapshot) {
      int newDue = 0;
      int reviewDue = 0;
      int totalLearned = 0;
      int totalWords = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final int assignedDay = data['assigned_day'] ?? 1;
        final int dueDay = data['due_day'] ?? 1;
        final int step = data['step'] ?? 0;

        if (step >= 2) totalLearned++;

        if (assignedDay == activeDay) {
          if (dueDay <= activeDay) newDue++;
        } else if (assignedDay < activeDay) {
          if (dueDay <= activeDay) reviewDue++;
        }
      }

      return {
        'new': math.min(newDue, newWordsPerDay),
        'review': math.min(reviewDue, maxReviewWordsPerDay),
        'total_learned': totalLearned,
        'total_words': totalWords,
      };
    });
  }

  // ─── Sıfırlama ────────────────────────────────────────────────────────────

  static Future<void> resetUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = _firestore.collection('users').doc(uid);
    final wordsCol = userDoc.collection('words');

    try {
      final wordSnap = await wordsCol.get();
      const int chunkSize = 400;
      for (int i = 0; i < wordSnap.docs.length; i += chunkSize) {
        final chunk = wordSnap.docs.sublist(
          i,
          math.min(i + chunkSize, wordSnap.docs.length),
        );
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('wordsCol reset error: $e');
    }

    _cachedDay = 1;
    _dayProgressCache.clear();

    DocumentSnapshot<Map<String, dynamic>>? userSnap;
    try {
      userSnap = await userDoc.get();
    } catch (_) {}

    final Map<String, dynamic> resetPayload = {
      'last_word_index': 0,
      'current_day': 1,
      'currentDay': 1,
      'day_progress': {},
      'streak': 0,
      'last_study_date': null,
      'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (userSnap != null && userSnap.exists && userSnap.data() != null) {
      // Eski part bazlı alanları temizle
      for (final key in userSnap.data()!.keys) {
        if (key.startsWith('day_') && key.endsWith('_progress')) {
          resetPayload[key] = FieldValue.delete();
        }
        if (key == 'days_progress') {
          resetPayload[key] = FieldValue.delete();
        }
      }
    } else {
      resetPayload['uid'] = uid;
      resetPayload['email'] = _auth.currentUser?.email ?? '';
      resetPayload['displayName'] = _auth.currentUser?.displayName ?? '';
      resetPayload['roles'] = ['staff'];
      resetPayload['isApproved'] = false;
      resetPayload['createdAt'] = FieldValue.serverTimestamp();
    }

    await userDoc.set(resetPayload, SetOptions(merge: true));
    await _ensureWordsForDay(1);
  }
}

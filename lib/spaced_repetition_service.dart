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

/// Part tamamlanma durumu.
class DayPartProgress {
  final bool part1Completed;
  final bool part2Completed;
  final bool part3Completed;
  final bool bonusNeeded;
  final bool bonusCompleted;
  final List<String> wrongWordsInSession;
  final int currentPart;
  final int reviewCount;

  const DayPartProgress({
    this.part1Completed = false,
    this.part2Completed = false,
    this.part3Completed = false,
    this.bonusNeeded = false,
    this.bonusCompleted = false,
    this.wrongWordsInSession = const [],
    this.currentPart = 1,
    this.reviewCount = 0,
  });

  factory DayPartProgress.fromMap(Map<String, dynamic> data) {
    final int curPart = (data['current_part'] ?? data['currentPart'] as num?)?.toInt() ?? 1;
    final bool p1 = data['part1_completed'] == true ||
        data['part1Completed'] == true ||
        curPart >= 2;
    final bool p2 = data['part2_completed'] == true ||
        data['part2Completed'] == true ||
        curPart >= 3;
    final bool p3 = data['part3_completed'] == true ||
        data['part3Completed'] == true ||
        curPart >= 4;
    final bool bNeeded =
        data['bonus_needed'] == true || data['bonusNeeded'] == true;
    final bool bDone =
        data['bonus_completed'] == true || data['bonusCompleted'] == true;

    final int inferredPart = p2 ? (p3 ? 4 : 3) : (p1 ? 2 : 1);

    return DayPartProgress(
      part1Completed: p1,
      part2Completed: p2,
      part3Completed: p3,
      bonusNeeded: bNeeded,
      bonusCompleted: bDone,
      wrongWordsInSession: List<String>.from(
          data['wrong_words_in_session'] ?? data['wrongWordsInSession'] ?? []),
      currentPart: curPart > 1 ? curPart : inferredPart,
      reviewCount:
          (data['review_count'] ?? data['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  DayPartProgress copyWith({
    bool? part1Completed,
    bool? part2Completed,
    bool? part3Completed,
    bool? bonusNeeded,
    bool? bonusCompleted,
    List<String>? wrongWordsInSession,
    int? currentPart,
    int? reviewCount,
  }) {
    return DayPartProgress(
      part1Completed: part1Completed ?? this.part1Completed,
      part2Completed: part2Completed ?? this.part2Completed,
      part3Completed: part3Completed ?? this.part3Completed,
      bonusNeeded: bonusNeeded ?? this.bonusNeeded,
      bonusCompleted: bonusCompleted ?? this.bonusCompleted,
      wrongWordsInSession: wrongWordsInSession ?? this.wrongWordsInSession,
      currentPart: currentPart ?? this.currentPart,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'part1_completed': part1Completed,
      'part2_completed': part2Completed,
      'part3_completed': part3Completed,
      'bonus_needed': bonusNeeded,
      'bonus_completed': bonusCompleted,
      'wrong_words_in_session': wrongWordsInSession,
      'current_part': currentPart,
      'currentPart': currentPart,
      'review_count': reviewCount,
    };
  }

  bool isPart3Complete({bool hasNoReviewWords = false}) =>
      part3Completed ||
      (part1Completed && part2Completed && hasNoReviewWords);

  bool isAllDone({bool hasNoReviewWords = false}) =>
      part1Completed &&
      part2Completed &&
      (part3Completed || hasNoReviewWords) &&
      (!bonusNeeded || bonusCompleted);

  bool get allDone => isAllDone();

  /// Tamamlanmamış ilk Part indeksini döndürür (0-based).
  /// Null: tüm part'lar bitti.
  int? getNextPartIndex({bool hasNoReviewWords = false}) {
    if (!part1Completed) return 0;
    if (!part2Completed) return 1;
    if (!part3Completed && !hasNoReviewWords) return 2;
    if (bonusNeeded && !bonusCompleted) return 3;
    return null;
  }

  int? get nextPartIndex => getNextPartIndex();
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

  static CollectionReference<Map<String, dynamic>>? _dayProgressCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('day_progress');
  }

  static int _cachedDay = 1;
  static final Map<int, DayPartProgress> _dayProgressCache = {};

  // ─── SRS Interval Tablosu ────────────────────────────────────────────────
  /// Step → gün aralığı (daha uzun, daha kalıcı hafıza için).
  static const List<int> _intervals = [
    0,   // Step 0: Yeni kelime, aynı gün
    1,   // Step 1: Ertesi gün
    3,   // Step 2: 3 gün sonra
    7,   // Step 3: 1 hafta
    14,  // Step 4: 2 hafta
    30,  // Step 5: 1 ay
    60,  // Step 6: 2 ay
    120, // Step 7: 4 ay
    365, // Step 8: 1 yıl (ustalaşmış)
  ];

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

  static List<String> getRandomDistractors(String correctWord, {int count = 3}) {
    if (_allWordsList == null || _allWordsList!.length <= count) {
      return ['example', 'target', 'word'];
    }
    final normalizedCorrect = correctWord.toLowerCase().trim();
    final distractors = <String>{};
    final random = math.Random();
    while (distractors.length < count) {
      final candidate = _allWordsList![random.nextInt(_allWordsList!.length)];
      if (candidate != normalizedCorrect) {
        distractors.add(candidate);
      }
    }
    return distractors.toList();
  }

  // ─── Kullanıcı Profili ────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> getUserProfileStream() {
    final doc = _userDoc();
    if (doc == null) {
      return Stream.value({
        'current_day': _cachedDay,
        'streak': 0,
      });
    }

    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      final streak = (data['streak'] as num?)?.toInt() ?? 0;

      final dbDay = (data['current_day'] as num?)?.toInt() ??
          (data['currentDay'] as num?)?.toInt();
      if (dbDay != null) _cachedDay = dbDay;

      final currentPart =
          (data['current_part'] ?? data['currentPart'] as num?)?.toInt() ?? 1;

      return {
        'current_day': _cachedDay,
        'currentDay': _cachedDay,
        'current_part': currentPart,
        'currentPart': currentPart,
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
            .difference(
                DateTime(lastDate.year, lastDate.month, lastDate.day))
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
      'weekly_activity': FieldValue.delete(),
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
        final dayProgress = await getDayPartProgress(safeDay);
        await doc.set({
          'current_day': safeDay,
          'currentDay': safeDay,
          'current_part': dayProgress.currentPart,
          'currentPart': dayProgress.currentPart,
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('setCurrentDay error: $e');
      }
    }
    await _ensureWordsForDay(safeDay);
  }

  // ─── Kelime Yükleme ────────────────────────────────────────────────────────

  /// Günlük 5 yeni kelime (eski 10'dan değiştirildi).
  static const int newWordsPerDay = 5;

  /// Günlük maksimum tekrar kelime sayısı.
  static const int maxReviewsPerDay = 20;

  static Future<void> initMockDataIfEmpty() async {
    await loadDictionaryIfNeeded();
    final currentDay = await getCurrentDay();
    await _ensureWordsForDay(currentDay);
  }

  static Future<void> _ensureWordsForDay(int day) async {
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
    // 5 kelime/gün ile indeks hesaplaması
    final startIndex = (day - 1) * newWordsPerDay;
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
          // Parantez içi metni _____ ile değiştir
          exampleEn = exampleEn.replaceAll(RegExp(r'\((.*?)\)'), '_____');
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

  // ─── Part Yönetimi ─────────────────────────────────────────────────────────

  static Future<DayPartProgress> getDayPartProgress(int day) async {
    if (_dayProgressCache.containsKey(day)) {
      return _dayProgressCache[day]!;
    }
    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        final snap = await userDocRef.get();
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          Map<String, dynamic>? dayMap;
          final daysProgress = data['days_progress'];
          if (daysProgress is Map && daysProgress['day_$day'] is Map) {
            dayMap = Map<String, dynamic>.from(daysProgress['day_$day']);
          }
          dayMap ??= (data['day_${day}_progress'] is Map)
              ? Map<String, dynamic>.from(data['day_${day}_progress'])
              : null;

          if (dayMap != null) {
            final res = DayPartProgress.fromMap(dayMap);
            _dayProgressCache[day] = res;
            return res;
          }
        }
      } catch (e) {
        debugPrint('userDoc getDayPartProgress error: $e');
      }
    }

    final col = _dayProgressCollection();
    if (col != null) {
      try {
        final snap = await col.doc('day_$day').get();
        if (snap.exists && snap.data() != null) {
          final res = DayPartProgress.fromMap(snap.data()!);
          _dayProgressCache[day] = res;
          return res;
        }
      } catch (e) {
        debugPrint('col getDayPartProgress error: $e');
      }
    }

    return const DayPartProgress();
  }

  static Stream<DayPartProgress> getDayPartProgressStream(int day) {
    final userDocRef = _userDoc();
    if (userDocRef == null) {
      return Stream.value(_dayProgressCache[day] ?? const DayPartProgress());
    }

    return userDocRef.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return _dayProgressCache[day] ?? const DayPartProgress();
      }
      final data = snap.data()!;
      Map<String, dynamic>? dayMap;
      final daysProgress = data['days_progress'];
      if (daysProgress is Map && daysProgress['day_$day'] is Map) {
        dayMap = Map<String, dynamic>.from(daysProgress['day_$day']);
      }
      dayMap ??= (data['day_${day}_progress'] is Map)
          ? Map<String, dynamic>.from(data['day_${day}_progress'])
          : null;

      if (dayMap != null) {
        final res = DayPartProgress.fromMap(dayMap);
        _dayProgressCache[day] = res;
        return res;
      }

      return _dayProgressCache[day] ?? const DayPartProgress();
    }).handleError((error) {
      debugPrint('getDayPartProgressStream error: $error');
      return _dayProgressCache[day] ?? const DayPartProgress();
    });
  }

  static int sessionPartToNumber(SessionPart part) {
    switch (part) {
      case SessionPart.introduction:
        return 1;
      case SessionPart.deepening:
        return 2;
      case SessionPart.review:
        return 3;
      case SessionPart.bonus:
        return 4;
    }
  }

  static Future<void> setCurrentPart(int day, SessionPart part) async {
    final partNum = sessionPartToNumber(part);
    _cachedDay = day;

    final existing = _dayProgressCache[day];
    if (existing != null) {
      _dayProgressCache[day] = existing.copyWith(currentPart: partNum);
    }

    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'current_day': day,
          'currentDay': day,
          'current_part': partNum,
          'currentPart': partNum,
          'current_part_name': part.name,
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('setCurrentPart userDoc error: $e');
      }
    }

    final col = _dayProgressCollection();
    if (col != null) {
      try {
        await col.doc('day_$day').set({
          'current_part': partNum,
          'currentPart': partNum,
          'current_part_name': part.name,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<void> markPartCompleted(
    int day,
    SessionPart part, {
    int? reviewCount,
  }) async {
    final Map<String, dynamic> update = {};
    int nextPartNum = 1;
    switch (part) {
      case SessionPart.introduction:
        update['part1_completed'] = true;
        nextPartNum = 2;
        break;
      case SessionPart.deepening:
        update['part2_completed'] = true;
        nextPartNum = 3;
        break;
      case SessionPart.review:
        update['part3_completed'] = true;
        nextPartNum = 4;
        if (reviewCount != null) {
          update['review_count'] = reviewCount;
        }
        break;
      case SessionPart.bonus:
        update['bonus_completed'] = true;
        nextPartNum = 4;
        break;
    }

    update['current_part'] = nextPartNum;
    update['currentPart'] = nextPartNum;
    update['updated_at'] = FieldValue.serverTimestamp();

    // 1. Önce in-memory cache'i hemen güncelle
    final existing = _dayProgressCache[day] ?? const DayPartProgress();
    _dayProgressCache[day] = existing.copyWith(
      part1Completed:
          part == SessionPart.introduction ? true : existing.part1Completed,
      part2Completed:
          part == SessionPart.deepening ? true : existing.part2Completed,
      part3Completed:
          part == SessionPart.review ? true : existing.part3Completed,
      bonusCompleted:
          part == SessionPart.bonus ? true : existing.bonusCompleted,
      currentPart: nextPartNum,
      reviewCount: reviewCount ?? existing.reviewCount,
    );

    // 2. userDoc'a kaydet (güvenli ve yetkisi kesin olan doküman)
    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'current_day': day,
          'currentDay': day,
          'current_part': nextPartNum,
          'currentPart': nextPartNum,
          'days_progress': {
            'day_$day': update,
          },
          'day_${day}_progress': update,
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('userDoc markPartCompleted error: $e');
      }
    }

    // 3. Subcollection'a da kaydetmeyi dene
    final col = _dayProgressCollection();
    if (col != null) {
      try {
        await col.doc('day_$day').set(update, SetOptions(merge: true));
      } catch (e) {
        debugPrint('col markPartCompleted error: $e');
      }
    }
  }

  static Future<void> updateWrongWordsInSession(
      int day, List<String> wrongWords) async {
    final bonusNeeded = wrongWords.length >= 2;
    final existing = _dayProgressCache[day] ?? const DayPartProgress();
    _dayProgressCache[day] = existing.copyWith(
      wrongWordsInSession: wrongWords,
      bonusNeeded: bonusNeeded,
    );

    final payload = {
      'wrong_words_in_session': wrongWords,
      'bonus_needed': bonusNeeded,
    };

    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'days_progress': {
            'day_$day': payload,
          },
          'day_${day}_progress': payload,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    final col = _dayProgressCollection();
    if (col != null) {
      try {
        await col.doc('day_$day').set(payload, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Belirtilen günün tüm verilerini sıfırlar (tekrar baştan başlatma için).
  static Future<void> resetDayProgress(int day) async {
    _dayProgressCache[day] = const DayPartProgress();

    final resetUpdate = {
      'part1_completed': false,
      'part2_completed': false,
      'part3_completed': false,
      'bonus_needed': false,
      'bonus_completed': false,
      'wrong_words_in_session': <String>[],
      'current_part': 1,
      'currentPart': 1,
      'review_count': 0,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // 1. userDoc'u sıfırla
    final userDocRef = _userDoc();
    if (userDocRef != null) {
      try {
        await userDocRef.set({
          'current_day': day,
          'currentDay': day,
          'current_part': 1,
          'currentPart': 1,
          'days_progress': {
            'day_$day': resetUpdate,
          },
          'day_${day}_progress': resetUpdate,
          'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('userDoc resetDayProgress error: $e');
      }
    }

    // 2. Subcollection'ı sıfırla
    final col = _dayProgressCollection();
    if (col != null) {
      try {
        await col.doc('day_$day').set(resetUpdate);
      } catch (_) {}
    }

    // 3. Günün kelimelerini sıfırla
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

        final reviewSnap =
            await wordsCol.where('last_reviewed_day', isEqualTo: day).get();
        for (var doc in reviewSnap.docs) {
          if (doc.data()['assigned_day'] != day) {
            batch.update(doc.reference, {
              'due_day': day,
              'next_review_date': Timestamp.fromDate(DateTime.now()),
              'last_reviewed_day': FieldValue.delete(),
            });
          }
        }

        await batch.commit();
      } catch (e) {
        debugPrint('words resetDayProgress error: $e');
      }
    }
  }

  // ─── Seans Kelime Getirme ─────────────────────────────────────────────────

  /// [day] için Part 1+2'de kullanılacak yeni kelimeleri döndürür.
  static Future<List<SpacedWord>> getNewWordsForDay(int day) async {
    await loadDictionaryIfNeeded();
    await _ensureWordsForDay(day);

    final collection = _userWordsCollection();
    if (collection == null) return [];

    final snap =
        await collection.where('assigned_day', isEqualTo: day).get();
    return snap.docs
        .map((doc) => SpacedWord.fromMap(doc.id, doc.data()))
        .take(newWordsPerDay)
        .toList();
  }

  /// [day] için Part 3'te kullanılacak tekrar kelimelerini döndürür.
  /// Step'e göre sıralanır: düşük step önce (daha zor, daha az pekişmiş).
  static Future<List<SpacedWord>> getReviewWordsForDay(int day) async {
    await loadDictionaryIfNeeded();

    final collection = _userWordsCollection();
    if (collection == null) return [];

    final snap = await collection.get();
    final List<SpacedWord> reviewWords = [];

    for (var doc in snap.docs) {
      final w = SpacedWord.fromMap(doc.id, doc.data());
      // Önceki günlerin kelimelerinden due olanlar
      if (w.assignedDay < day && w.dueDay <= day) {
        reviewWords.add(w);
      }
    }

    // Step'e göre sırala (düşük step → daha fazla tekrar ihtiyacı)
    reviewWords.sort((a, b) => a.step.compareTo(b.step));
    return reviewWords.take(maxReviewsPerDay).toList();
  }

  /// Eski `getSessionForDay` — geriye dönük uyumluluk için korunur.
  static Future<List<SpacedWord>> getSessionForDay(int activeDay) async {
    await loadDictionaryIfNeeded();
    await _ensureWordsForDay(activeDay);

    final collection = _userWordsCollection();
    if (collection == null) return [];

    final snapshot = await collection.get();
    List<SpacedWord> newWords = [];
    List<SpacedWord> reviewWords = [];

    for (var doc in snapshot.docs) {
      final w = SpacedWord.fromMap(doc.id, doc.data());
      if (w.assignedDay == activeDay && w.dueDay <= activeDay) {
        newWords.add(w);
      } else if (w.assignedDay < activeDay && w.dueDay <= activeDay) {
        reviewWords.add(w);
      }
    }

    newWords = newWords.take(newWordsPerDay).toList();
    reviewWords = reviewWords.take(maxReviewsPerDay).toList();

    final allWords = [...newWords, ...reviewWords];
    allWords.shuffle();
    return allWords;
  }

  // ─── Egzersiz Tipi Belirleme ───────────────────────────────────────────────

  /// [step] seviyesine göre Part 3 için uygun egzersiz tipini döndürür.
  static ExerciseType getExerciseTypeForStep(int step) {
    if (step <= 1) return ExerciseType.hintedWriting;
    if (step <= 3) return ExerciseType.trToEnWriting;
    if (step <= 5) return ExerciseType.clozeWriting;
    return ExerciseType.listeningWriting;
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
        // Yanlışta 2 adım geri (planlandığı gibi)
        step = (step > 2) ? step - 2 : 0;
        wrongCount++;
      }

      final intervalDays = _intervals[step];
      final nextDueDay = day + (isCorrect ? intervalDays : 1);
      final mastered = step >= 6;

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
        'review': math.min(reviewDue, maxReviewsPerDay),
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
    final progressCol = userDoc.collection('day_progress');

    // 1. Kelime dokümanlarını sil
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

    // 2. Gün ilerleme alt koleksiyonunu sil (izin yoksa bile akışı bozmaz)
    try {
      final progressSnap = await progressCol.get();
      const int chunkSize = 400;
      for (int i = 0; i < progressSnap.docs.length; i += chunkSize) {
        final chunk = progressSnap.docs.sublist(
          i,
          math.min(i + chunkSize, progressSnap.docs.length),
        );
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('progressCol reset error: $e');
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
      'current_part': 1,
      'currentPart': 1,
      'current_part_name': 'introduction',
      'days_progress': {},
      'streak': 0,
      'weekly_activity': FieldValue.delete(),
      'last_study_date': null,
      'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (userSnap != null && userSnap.exists && userSnap.data() != null) {
      for (final key in userSnap.data()!.keys) {
        if (key.startsWith('day_') && key.endsWith('_progress')) {
          resetPayload[key] = FieldValue.delete();
        }
      }
    } else {
      // Eğer doküman henüz yoksa create kurallarını karşılayacak alanları ekle
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

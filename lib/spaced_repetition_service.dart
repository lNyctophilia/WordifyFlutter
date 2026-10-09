import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math' as math;

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
    };
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

  /// Kullanıcı profil verilerini (seri, haftalık aktivite vb.) izleyen Stream
  static Stream<Map<String, dynamic>> getUserProfileStream() {
    final doc = _userDoc();
    if (doc == null) {
      return Stream.value({
        'current_day': 1,
        'streak': 0,
        'weekly_activity': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      });
    }

    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      final streak = (data['streak'] as num?)?.toInt() ?? 0;
      final rawActivity = data['weekly_activity'];
      List<double> activity = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      if (rawActivity is List) {
        activity = rawActivity.map((e) => ((e as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0)).toList();
        while (activity.length < 7) {
          activity.add(0.0);
        }
      }

      return {
        'current_day': (data['current_day'] as num?)?.toInt() ?? 1,
        'streak': streak,
        'weekly_activity': activity,
      };
    });
  }

  /// Çalışma aktivitesini kaydet (Seri ve haftalık aktiviteyi artırır)
  static Future<void> recordStudyActivity() async {
    final doc = _userDoc();
    if (doc == null) return;

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekdayIndex = now.weekday - 1; // 0: Pzt, ..., 6: Paz

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

    List<double> activity = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final rawActivity = data['weekly_activity'];
    if (rawActivity is List) {
      activity = rawActivity.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
      while (activity.length < 7) {
        activity.add(0.0);
      }
    }
    // İlgili günün barını artır (en fazla 1.0)
    activity[weekdayIndex] = (activity[weekdayIndex] + 0.1).clamp(0.0, 1.0);

    await doc.set({
      'streak': streak,
      'last_study_date': todayStr,
      'weekly_activity': activity,
    }, SetOptions(merge: true));
  }

  // SM-2 Algoritması gün aralıkları
  static const List<int> _intervals = [
    0,    // Adım 0: Aynı gün
    1,    // Adım 1: 1 gün sonra
    2,    // Adım 2: 2 gün sonra
    4,    // Adım 3: 4 gün sonra
    7,    // Adım 4: 7 gün sonra (1 hafta)
    16,   // Adım 5: 16 gün sonra
    35,   // Adım 6: 35 gün sonra (~1 ay)
    90,   // Adım 7: 90 gün sonra (~3 ay)
    180,  // Adım 8: 180 gün sonra (~6 ay)
  ];

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

  static Future<void> initMockDataIfEmpty() async {
    await loadDictionaryIfNeeded();
    final currentDay = await getCurrentDay();
    await _ensureWordsForDay(currentDay);
  }

  /// Kullanıcının aktif gününü izleyen Stream
  static Stream<int> getUserDayStream() {
    final doc = _userDoc();
    if (doc == null) return Stream.value(1);
    return doc.snapshots().map((snapshot) {
      return (snapshot.data()?['current_day'] as num?)?.toInt() ?? 1;
    });
  }

  /// Kullanıcının kayıtlı gününü getirme
  static Future<int> getCurrentDay() async {
    final doc = _userDoc();
    if (doc == null) return 1;
    final snap = await doc.get();
    return (snap.data()?['current_day'] as num?)?.toInt() ?? 1;
  }

  /// Aktif günü veritabanında güncelleme
  static Future<void> setCurrentDay(int day) async {
    final safeDay = math.max(1, day);
    final doc = _userDoc();
    if (doc == null) return;
    await doc.set({'current_day': safeDay}, SetOptions(merge: true));
    await _ensureWordsForDay(safeDay);
  }

  /// İlgili güne ait 10 yeni kelimeyi listeye dahil etme
  static Future<void> _ensureWordsForDay(int day) async {
    await loadDictionaryIfNeeded();
    final collection = _userWordsCollection();
    if (collection == null) return;

    // Bu güne atanmış kelimeler var mı kontrol et
    final existingSnap = await collection.where('assigned_day', isEqualTo: day).get();
    if (existingSnap.docs.isNotEmpty) return;

    String fileText = '';
    try {
      fileText = await rootBundle.loadString('assets/en_tr_word_list.txt');
    } catch (e) {
      debugPrint('Failed to load word list asset: $e');
      return;
    }

    final List<String> lines = const LineSplitter().convert(fileText);
    final startIndex = (day - 1) * 10;
    if (startIndex >= lines.length) return;

    final batch = _firestore.batch();
    int added = 0;

    for (int i = startIndex; i < lines.length && added < 10; i++) {
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
          exampleEn = exampleEn.replaceAll(RegExp(r'\((.*?)\)'), '________');
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
        }, SetOptions(merge: true));
        added++;
      }
    }

    if (added > 0) {
      await batch.commit();
    }
  }

  static Future<void> resetUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = _firestore.collection('users').doc(uid);
    final collection = userDoc.collection('words');

    final snapshot = await collection.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.set(userDoc, {
      'last_word_index': 0,
      'current_day': 1,
    }, SetOptions(merge: true));

    await batch.commit();
    await _ensureWordsForDay(1);
  }

  /// Seçili güne özel istatistikleri dinleyen Stream
  static Stream<Map<String, int>> getStatsStreamForDay(int activeDay) {
    final collection = _userWordsCollection();
    if (collection == null) return Stream.value({'new': 0, 'review': 0, 'total_learned': 0, 'total_words': 0});

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

        if (step >= 2) {
          totalLearned++;
        }

        if (assignedDay == activeDay) {
          // O günün yeni kelimesi henüz bitirilmemişse
          if (dueDay <= activeDay) {
            newDue++;
          }
        } else if (assignedDay < activeDay) {
          // Önceki günlerden gelen tekrar kelimesi
          if (dueDay <= activeDay) {
            reviewDue++;
          }
        }
      }

      return {
        'new': newDue,
        'review': reviewDue,
        'total_learned': totalLearned,
        'total_words': totalWords,
      };
    });
  }

  /// Seçili gün için seans kelimelerini getirme
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

    newWords = newWords.take(10).toList();
    reviewWords = reviewWords.take(25).toList();

    final allWords = [...newWords, ...reviewWords];
    allWords.shuffle();
    return allWords;
  }

  /// Cevap sonucunda kelimenin adımını ve sıradaki gününü güncelleme
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

      if (isCorrect) {
        if (step < _intervals.length - 1) {
          step++;
        }
      } else {
        step = (step > 1) ? step - 1 : 0;
      }

      final intervalDays = _intervals[step];
      final nextDueDay = day + (isCorrect ? intervalDays : 1);

      transaction.update(docRef, {
        'step': step,
        'due_day': nextDueDay,
        'next_review_date': Timestamp.fromDate(
          DateTime.now().add(Duration(days: intervalDays)),
        ),
        'is_learning': step <= 1,
      });
    });

    await recordStudyActivity();
  }
}

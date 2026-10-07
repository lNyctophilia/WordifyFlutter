import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class SpacedWord {
  final String id;
  final String wordEn;
  final String wordTr;
  final String? exampleSentence;
  final DateTime nextReviewDate;
  final int step;
  final bool isLearning;

  SpacedWord({
    required this.id,
    required this.wordEn,
    required this.wordTr,
    this.exampleSentence,
    required this.nextReviewDate,
    required this.step,
    required this.isLearning,
  });

  factory SpacedWord.fromMap(String id, Map<String, dynamic> data) {
    return SpacedWord(
      id: id,
      wordEn: data['word_en'] ?? '',
      wordTr: data['word_tr'] ?? '',
      exampleSentence: data['example_sentence'],
      nextReviewDate: (data['next_review_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      step: data['step'] ?? 0,
      isLearning: data['is_learning'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word_en': wordEn,
      'word_tr': wordTr,
      'example_sentence': exampleSentence,
      'next_review_date': Timestamp.fromDate(nextReviewDate),
      'step': step,
      'is_learning': isLearning,
    };
  }
}

class SpacedRepetitionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>>? _userWordsCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('words');
  }

  // SM-2 Algorithm intervals (in days)
  static const List<double> _intervals = [
    0.0,    // Step 0: Immediate/Same Day
    0.5,    // Step 1: Same Day / +12 hours
    1.0,    // Step 2: 1 day
    3.0,    // Step 3: 3 days
    7.0,    // Step 4: 7 days
    16.0,   // Step 5: 16 days
    35.0,   // Step 6: 35 days
    90.0,   // Step 7: 90 days
    180.0,  // Step 8: 180 days
  ];

  static Future<void> initMockDataIfEmpty() async {
    // Left for backwards compatibility if called, but logic is handled in _pullNewWordsIfNeeded
  }

  static Future<void> _pullNewWordsIfNeeded(int neededCount) async {
    if (neededCount <= 0) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = _firestore.collection('users').doc(uid);
    final userSnapshot = await userDoc.get();
    int lastWordIndex = userSnapshot.data()?['last_word_index'] ?? 0;

    String fileText = '';
    try {
      fileText = await rootBundle.loadString('assets/en_tr_word_list.txt');
    } catch (e) {
      debugPrint('Failed to load word list asset: $e');
      return;
    }

    final List<String> lines = const LineSplitter().convert(fileText);

    final collection = _userWordsCollection();
    if (collection == null) return;

    int addedCount = 0;
    final batch = _firestore.batch();

    while (addedCount < neededCount && lastWordIndex < lines.length) {
      final line = lines[lastWordIndex];
      lastWordIndex++;

      if (line.trim().isEmpty) continue;

      final parts = line.split(' - ');
      if (parts.length >= 2) {
        final wordEn = parts[0].trim();
        final wordTr = parts[1].trim();
        String exampleEn = '';
        if (parts.length >= 4) {
          exampleEn = parts[3].trim();
        }

        final docRef = collection.doc(wordEn);
        batch.set(docRef, {
          'word_en': wordEn,
          'word_tr': wordTr,
          'example_sentence': exampleEn.isNotEmpty ? exampleEn : 'The translated word is: $wordTr',
          'next_review_date': FieldValue.serverTimestamp(),
          'step': 0,
          'is_learning': true,
        });
        addedCount++;
      }
    }

    if (addedCount > 0) {
      batch.set(userDoc, {'last_word_index': lastWordIndex}, SetOptions(merge: true));
      await batch.commit();
    }
  }

  static Future<void> resetUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = _firestore.collection('users').doc(uid);
    final collection = userDoc.collection('words');
    
    // Delete all words in batches
    final snapshot = await collection.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Reset index
    batch.set(userDoc, {'last_word_index': 0}, SetOptions(merge: true));
    
    await batch.commit();
  }

  /// Get today's goal stats (new vs review)
  static Stream<Map<String, int>> getTodayStatsStream() {
    final collection = _userWordsCollection();
    if (collection == null) return Stream.value({'new': 0, 'review': 0, 'total_learned': 0});

    final now = DateTime.now();

    return collection.snapshots().map((snapshot) {
      int newWords = 0;
      int reviewWords = 0;
      int totalLearned = 0;
      int totalWords = snapshot.docs.length;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isLearning = data['is_learning'] ?? true;
        final nextReview = (data['next_review_date'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (!isLearning) {
          totalLearned++;
        }

        if (nextReview.isBefore(now) || nextReview.isAtSameMomentAs(now)) {
          if (isLearning) {
            newWords++;
          } else {
            reviewWords++;
          }
        }
      }
      return {
        'new': newWords,
        'review': reviewWords,
        'total_learned': totalLearned,
        'total_words': totalWords,
      };
    });
  }

  /// Get today's session words (e.g. limit 10 new, limit 25 review)
  static Future<List<SpacedWord>> getTodaySession() async {
    final collection = _userWordsCollection();
    if (collection == null) return [];

    final now = DateTime.now();

    var snapshot = await collection
        .where('next_review_date', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    int newWordsCount = 0;
    for (var doc in snapshot.docs) {
      if (doc.data()['is_learning'] == true) {
        newWordsCount++;
      }
    }

    // If we have less than 10 new words due, pull from the txt file
    if (newWordsCount < 10) {
      await _pullNewWordsIfNeeded(10 - newWordsCount);
      // Re-fetch after adding new words
      snapshot = await collection
          .where('next_review_date', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();
    }

    List<SpacedWord> newWords = [];
    List<SpacedWord> reviewWords = [];

    for (var doc in snapshot.docs) {
      final w = SpacedWord.fromMap(doc.id, doc.data());
      if (w.isLearning) {
        newWords.add(w);
      } else {
        reviewWords.add(w);
      }
    }

    // Limit based on rules
    newWords = newWords.take(10).toList();
    reviewWords = reviewWords.take(25).toList();

    final allWords = [...newWords, ...reviewWords];
    allWords.shuffle(); // mix new and review words
    return allWords;
  }

  /// Process an answer and update SRS step
  static Future<void> updateWordProgress(String wordId, bool isCorrect) async {
    final collection = _userWordsCollection();
    if (collection == null) return;

    final docRef = collection.doc(wordId);
    
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int step = data['step'] ?? 0;

      if (isCorrect) {
        if (step < _intervals.length - 1) {
          step++;
        }
      } else {
        step = (step > 2) ? step - 2 : 0;
      }

      final intervalDays = _intervals[step];
      final nextDate = DateTime.now().add(Duration(hours: (intervalDays * 24).round()));

      transaction.update(docRef, {
        'step': step,
        'next_review_date': Timestamp.fromDate(nextDate),
        'is_learning': step <= 1, 
      });
    });
  }
}

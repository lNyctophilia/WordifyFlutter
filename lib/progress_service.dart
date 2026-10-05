import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>>? _userDocRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  static Stream<int> get currentDayStream {
    final ref = _userDocRef();
    if (ref == null) {
      return Stream.value(1);
    }

    return ref.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return 1;
      }
      final data = snapshot.data()!;
      final day = data['currentDay'];
      if (day is int && day > 0) {
        return day;
      }
      return 1;
    }).handleError((error) {
      debugPrint('Firestore progress stream error: $error');
      return 1;
    });
  }

  static Future<void> updateCurrentDay(int day) async {
    final ref = _userDocRef();
    if (ref == null) return;

    try {
      await ref.set({
        'currentDay': day,
        'lastProgressUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore progress update error: $e');
    }
  }
}

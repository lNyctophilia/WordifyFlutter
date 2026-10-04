import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rate Limiting: Kısa sürede sürekli yeni hesap açma ve sık gir-çık koruması
  static final List<DateTime> _recentLogins = [];
  static const int _maxAttemptsWindowMinutes = 3;
  static const int _maxAttempts = 4;
  static const int _cooldownSeconds = 60;
  static DateTime? _cooldownUntil;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> signInWithGoogle() async {
    final now = DateTime.now();

    // Bekleme süresi (Cooldown) kontrolü
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      final remaining = _cooldownUntil!.difference(now).inSeconds;
      throw Exception(
        'Güvenlik nedeniyle geçici sınırlandırma aktif. Lütfen $remaining saniye sonra tekrar deneyin.',
      );
    }

    // Zaman penceresi dışındaki eski kayıtları temizle
    _recentLogins.removeWhere(
      (dt) => now.difference(dt).inMinutes >= _maxAttemptsWindowMinutes,
    );

    // Limit aşıldıysa cooldown başlat
    if (_recentLogins.length >= _maxAttempts) {
      _cooldownUntil = now.add(const Duration(seconds: _cooldownSeconds));
      throw Exception(
        'Çok sık giriş/hesap değiştirme denemesi yapıldı. Güvenliğiniz için $_cooldownSeconds saniye bekleyin.',
      );
    }

    _recentLogins.add(now);

    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');
    googleProvider.setCustomParameters({'prompt': 'select_account'});

    final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(googleProvider);
    } else {
      credential = await _auth.signInWithProvider(googleProvider);
    }

    // Firestore kullanıcı senkronizasyonu (arka planda sessiz)
    final user = credential.user;
    if (user != null) {
      _syncUserData(user).catchError((e) {
        debugPrint('Firestore sync hatası (opsiyonel): $e');
      });
    }

    return credential;
  }

  static Future<void> _syncUserData(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'roles': ['staff'],
          'isApproved': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Firestore sync hatası: $e');
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}

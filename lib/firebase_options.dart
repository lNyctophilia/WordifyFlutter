// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default [FirebaseOptions] for Wordify Web.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBKeYxD9VONGKwb1NF4hf-1KmFpKfJsXSs',
    appId: '1:773824098060:web:aebf612bc3c7f0786ca329',
    messagingSenderId: '773824098060',
    projectId: 'wordify-58603',
    authDomain: 'wordify-58603.firebaseapp.com',
    storageBucket: 'wordify-58603.firebasestorage.app',
  );
}

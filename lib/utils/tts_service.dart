import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48); // Öğrenmeye uygun net telaffuz hızı
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }
}

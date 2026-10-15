import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_bridge.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> init() async {
    bridgeInit();
    if (_isInitialized) return;
    if (!kIsWeb) {
      try {
        await _flutterTts.setLanguage('en-US');
        await _flutterTts.setSpeechRate(0.48); // Öğrenmeye uygun net telaffuz hızı
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setPitch(1.0);
        _isInitialized = true;
      } catch (e) {
        debugPrint('TTS initialization error: $e');
      }
    } else {
      _isInitialized = true;
    }
  }

  static Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await stop();
    if (bridgeSpeak(clean)) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.stop();
      await _flutterTts.speak(clean);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  static Future<void> stop() async {
    if (bridgeStopSpeech()) return;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }
}


import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void bridgeInit() {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('unlock'.toJS);
    }
  } catch (e) {
    debugPrint('audio bridge init error: $e');
  }
}

bool bridgePlayCorrect() {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('playCorrect'.toJS);
      return true;
    }
  } catch (e) {
    debugPrint('bridgePlayCorrect error: $e');
  }
  return false;
}

bool bridgePlayWrong() {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('playWrong'.toJS);
      return true;
    }
  } catch (e) {
    debugPrint('bridgePlayWrong error: $e');
  }
  return false;
}

bool bridgePlayFinish() {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('playFinish'.toJS);
      return true;
    }
  } catch (e) {
    debugPrint('bridgePlayFinish error: $e');
  }
  return false;
}

bool bridgeSpeak(String text) {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('speak'.toJS, text.toJS);
      return true;
    }
  } catch (e) {
    debugPrint('bridgeSpeak error: $e');
  }
  return false;
}

bool bridgeStopSpeech() {
  try {
    if (web.window.hasProperty('WordifyAudio'.toJS).toDart) {
      final audioObj = web.window.getProperty('WordifyAudio'.toJS) as JSObject?;
      audioObj?.callMethod('stopSpeech'.toJS);
      return true;
    }
  } catch (e) {
    debugPrint('bridgeStopSpeech error: $e');
  }
  return false;
}

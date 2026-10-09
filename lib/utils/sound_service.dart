import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static Uint8List? _correctWav;
  static Uint8List? _wrongWav;
  static Uint8List? _finishWav;

  static void init() {
    _correctWav = _generateCorrectSound();
    _wrongWav = _generateWrongSound();
    _finishWav = _generateFinishSound();
  }

  static Future<void> playCorrect() async {
    try {
      _correctWav ??= _generateCorrectSound();
      await _player.stop();
      await _player.play(BytesSource(_correctWav!));
    } catch (e) {
      debugPrint('Error playing correct sound: $e');
    }
  }

  static Future<void> playWrong() async {
    try {
      _wrongWav ??= _generateWrongSound();
      await _player.stop();
      await _player.play(BytesSource(_wrongWav!));
    } catch (e) {
      debugPrint('Error playing wrong sound: $e');
    }
  }

  static Future<void> playFinish() async {
    try {
      _finishWav ??= _generateFinishSound();
      await _player.stop();
      await _player.play(BytesSource(_finishWav!));
    } catch (e) {
      debugPrint('Error playing finish sound: $e');
    }
  }

  /// Builds a standard 16-bit mono PCM WAV file from generated floating-point samples.
  static Uint8List _createWav(List<double> samples, int sampleRate) {
    final int byteRate = sampleRate * 2;
    final int dataSize = samples.length * 2;
    final int chunkSize = 36 + dataSize;

    final ByteData header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, chunkSize, Endian.little);
    // WAVE
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt 
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    header.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);  // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample
    // data
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final Uint8List wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());

    final ByteData pcmData = ByteData.sublistView(wavBytes, 44);
    for (int i = 0; i < samples.length; i++) {
      final double clamped = samples[i].clamp(-1.0, 1.0);
      final int sampleInt = (clamped * 32767).round();
      pcmData.setInt16(i * 2, sampleInt, Endian.little);
    }

    return wavBytes;
  }

  /// Doğru cevap sesi: Tatlı, iki kademeli yükselen parlak zil tonu (587 Hz -> 880 Hz)
  static Uint8List _generateCorrectSound() {
    const int sampleRate = 22050;
    const double duration = 0.35;
    final int totalSamples = (sampleRate * duration).round();
    final List<double> samples = List<double>.filled(totalSamples, 0.0);

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double freq = t < 0.1 ? 587.33 : 880.0;
      final double envelope = exp(-t * 8.0);
      samples[i] = sin(2 * pi * freq * t) * envelope * 0.45;
    }

    return _createWav(samples, sampleRate);
  }

  /// Yanlış cevap sesi: Yumuşak alçalan hata tonu (220 Hz -> 150 Hz)
  static Uint8List _generateWrongSound() {
    const int sampleRate = 22050;
    const double duration = 0.28;
    final int totalSamples = (sampleRate * duration).round();
    final List<double> samples = List<double>.filled(totalSamples, 0.0);

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 220.0 - (t / duration) * 70.0;
      final double envelope = exp(-t * 9.0);
      // Hafif harmonikli yumuşak ses
      final double wave = 0.7 * sin(2 * pi * freq * t) + 0.3 * sin(4 * pi * freq * t);
      samples[i] = wave * envelope * 0.45;
    }

    return _createWav(samples, sampleRate);
  }

  /// Bitiş kutlama sesi: 4 notalı zafer akoru (C5 -> E5 -> G5 -> C6)
  static Uint8List _generateFinishSound() {
    const int sampleRate = 22050;
    const double duration = 1.1;
    final int totalSamples = (sampleRate * duration).round();
    final List<double> samples = List<double>.filled(totalSamples, 0.0);

    final notes = [
      {'start': 0.00, 'freq': 523.25, 'dur': 0.25}, // C5
      {'start': 0.18, 'freq': 659.25, 'dur': 0.25}, // E5
      {'start': 0.36, 'freq': 783.99, 'dur': 0.28}, // G5
      {'start': 0.54, 'freq': 1046.50, 'dur': 0.55}, // C6
    ];

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      double sample = 0.0;

      for (final note in notes) {
        final double start = note['start'] as double;
        final double freq = note['freq'] as double;
        final double dur = note['dur'] as double;

        if (t >= start && t < start + dur) {
          final double localT = t - start;
          final double env = exp(-localT * 4.5);
          sample += sin(2 * pi * freq * localT) * env * 0.35;
        }
      }
      samples[i] = sample;
    }

    return _createWav(samples, sampleRate);
  }
}

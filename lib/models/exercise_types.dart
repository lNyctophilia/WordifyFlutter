// Egzersiz tipleri ve seans yapısı modelleri

/// Kullanıcıdan şık seçimi beklenmez, tüm tipler yazma tabanlıdır.
enum ExerciseType {
  /// 1. Tanıtım kartı: Kelime EN+TR+örnek gösterilir, TTS otomatik okur.
  ///    Kullanıcı sadece "Öğrendim" butonuna basar. Step değişmez.
  flashcard,

  /// 2. Türkçe anlam gösterilir → kullanıcı İngilizcesini yazar.
  trToEnWriting,

  /// 3. İngilizce kelime gösterilir + TTS okur → kullanıcı Türkçesini yazar.
  enToTrWriting,

  /// 4. İngilizce cümle boşluklu gösterilir (Türkçe cümle ipucu ile) → kullanıcı yazar.
  clozeWriting,

  /// 5. Sadece TTS ile kelime okunur, ekranda yazı yok → kullanıcı duyduğunu yazar.
  listeningWriting,

  /// 6. Türkçe anlam + ilk harf + uzunluk ipucu → kullanıcı yazar.
  hintedWriting,
}

/// Günlük seansin 3 (+ opsiyonel bonus) bölümü.
enum SessionPart {
  /// Part 1: 5 yeni kelimenin flashcard tanıtımı + TR→EN yazma turu.
  introduction,

  /// Part 2: Aynı 5 kelime için EN→TR yazma + cümle boşluk turu.
  deepening,

  /// Part 3: SRS'e göre due olan eski kelimeler — step'e göre zorluk.
  review,

  /// Bonus: Seans içinde 2+ kez yanlış bilinen kelimeler için ek tekrar.
  bonus,
}

/// Bir soru kartını temsil eder.
class ExerciseQuestion {
  final ExerciseType type;
  final SessionPart part;

  /// Kelimenin Firestore'daki belgesi ID'si (kelime İngilizce).
  final String wordId;

  /// İngilizce kelime ya da kalıp.
  final String wordEn;

  /// Türkçe anlam(lar). "/" ile birden fazla olabilir (ör. "hasta / sabırlı").
  final String wordTr;

  /// İngilizce örnek cümle. Boşluk doldurmada _____ içerir.
  final String? sentenceEn;

  /// Türkçe örnek cümle (ipucu olarak gösterilir).
  final String? sentenceTr;

  /// Spaced repetition adımı (step) — egzersiz seçimi için.
  final int step;

  ExerciseQuestion({
    required this.type,
    required this.part,
    required this.wordId,
    required this.wordEn,
    required this.wordTr,
    this.sentenceEn,
    this.sentenceTr,
    required this.step,
  });

  /// İlk harf + uzunluk ipucu (hintedWriting için).
  String get hintText {
    if (wordEn.isEmpty) return '';
    return wordEn[0] + List.generate(wordEn.length - 1, (_) => ' _').join('');
  }

  /// Kelimenin okunacak formu (phrasal verb'lerde tam kalıp).
  String get speakText => wordEn;
}

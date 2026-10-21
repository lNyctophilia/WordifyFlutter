// Egzersiz tipleri ve seans yapısı modelleri

/// 4 cümle bazlı soru tipi.
/// Hiçbirinde salt kelime sorulmaz — her zaman cümle bağlamı vardır.
/// Soru sırasında TTS yoktur. Sadece doğru cevap feedback ekranında
/// İngilizce kelime seslendirilir.
enum ExerciseType {
  /// Tip 1: İngilizce cümle + (Türkçe kelime) → İngilizce cevap
  /// Örnek: "The doctor cared for the (hasta)." → "patient"
  sentenceEnWithTr,

  /// Tip 2: İngilizce cümle + (İngilizce kelime) → Türkçe cevap
  /// Örnek: "The doctor cared for the (patient)." → "hasta"
  sentenceEnWithEn,

  /// Tip 3: Türkçe cümle + (İngilizce kelime) → Türkçe cevap
  /// Örnek: "Doktor (patient) ile yakından ilgilendi." → "hasta"
  sentenceTrWithEn,

  /// Tip 4: Türkçe cümle + (Türkçe kelime) → İngilizce cevap
  /// Örnek: "Doktor (hasta) ile yakından ilgilendi." → "patient"
  sentenceTrWithTr,
}

/// İstenen cevap dili.
enum AnswerDirection {
  /// Kullanıcıdan İngilizce kelime beklenir.
  toEnglish,

  /// Kullanıcıdan Türkçe anlam beklenir.
  toTurkish,
}

/// Günlük seansin part'ları (1-4).
enum SessionPart {
  part1,
  part2,
  part3,
  part4,
}

/// Gün tipi: Yeni kelime öğrenme mi, yoksa eski tekrar mı.
enum DayType {
  /// Öğrenme günü: 5 yeni kelime, 4 part, ~40 soru.
  learning,

  /// Tekrar günü: SRS'e göre due olan eski kelimeler.
  /// Her 5 günde bir (Gün 5, 10, 15...).
  review,
}

/// Bir soru kartını temsil eder.
class ExerciseQuestion {
  final ExerciseType type;
  final SessionPart part;
  final AnswerDirection direction;

  /// Kelimenin Firestore'daki belgesi ID'si.
  final String wordId;

  /// İngilizce kelime.
  final String wordEn;

  /// Türkçe anlam(lar). "/" ile birden fazla olabilir.
  final String wordTr;

  /// İngilizce örnek cümle. Hedef kelimenin yerine
  /// Tip 1'de (Türkçesi) veya Tip 2'de (İngilizcesi) parantez içinde gösterilir.
  final String? sentenceEn;

  /// Türkçe örnek cümle. Hedef kelimenin yerine
  /// Tip 3'te (İngilizcesi) veya Tip 4'te (Türkçesi) parantez içinde gösterilir.
  final String? sentenceTr;

  /// Spaced repetition adımı.
  final int step;

  /// Soru için seçilen cümleyle eşleşen Türkçe anlam (parantez görünümü için).
  /// Validasyon için değil, sadece cümle içi gösterimde kullanılır.
  final String matchedTrMeaning;

  ExerciseQuestion({
    required this.type,
    required this.part,
    required this.direction,
    required this.wordId,
    required this.wordEn,
    required this.wordTr,
    required this.matchedTrMeaning,
    this.sentenceEn,
    this.sentenceTr,
    required this.step,
  });
}

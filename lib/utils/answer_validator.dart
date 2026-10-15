/// Cevap doğrulama yardımcısı.
///
/// Desteklenen kurallar:
/// - Büyük/küçük harf fark etmez.
/// - Baştaki/sondaki boşluklar görmezden gelinir.
/// - "hasta / sabırlı" gibi "/" ile ayrılmış çoklu Türkçe anlamlardan
///   biri yazılırsa doğru sayılır.
/// - Aynı kural İngilizce "come / arrive" gibi tanımlarda da çalışır.
class AnswerValidator {
  /// [userInput] : Kullanıcının girdiği metin.
  /// [correctAnswer] : Beklenen cevap (tek veya "/" ile birden fazla anlam).
  static bool isCorrect(String userInput, String correctAnswer) {
    final normalized = _normalize(userInput);
    if (normalized.isEmpty) return false;

    final variants = correctAnswer
        .split('/')
        .map(_normalize)
        .where((v) => v.isNotEmpty)
        .toList();

    return variants.any((v) => v == normalized);
  }

  /// İngilizce kelimeye karşı doğrulama (TR→EN ve cümle boşluk modu).
  /// Phrasal verb'lerde de kullanılır (ör. "come into").
  static bool isEnglishCorrect(String userInput, String wordEn) {
    return _normalize(userInput) == _normalize(wordEn);
  }

  /// Türkçe cevaba karşı doğrulama (EN→TR modu).
  /// "/" ile ayrılmış alternatiflerin herhangi biri kabul edilir.
  static bool isTurkishCorrect(String userInput, String wordTr) {
    return isCorrect(userInput, wordTr);
  }

  static String _normalize(String text) {
    return text.trim().toLowerCase();
  }

  /// Kullanıcının girdiği cevabın hangi alternatiflerle eşleştiğini
  /// açıklayan bir metin döndürür (yanlış cevap ekranında kullanılır).
  static String? getMatchedAlternative(String userInput, String correctAnswer) {
    final normalized = _normalize(userInput);
    final variants = correctAnswer.split('/').map((v) => v.trim()).toList();
    for (final v in variants) {
      if (_normalize(v) == normalized) return v;
    }
    return null;
  }

  /// Mevcut TTS'in okuyacağı temiz İngilizce metni döndürür.
  /// Parantez içi meta-bilgileri temizler: "(to) go" → "go"
  static String cleanForTts(String wordEn) {
    return wordEn.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  }
}

import 'dart:io';

void main() {
  final now = DateTime.now();
  final day = now.day.toString().padLeft(2, '0');
  final month = now.month.toString().padLeft(2, '0');
  final year = now.year.toString();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');

  final dateStr = '$day.$month.$year';
  final timeStr = '$hour.$minute';
  final fullVersion = 'Versiyon ($dateStr-$timeStr)';

  final content = '''class AppConfig {
  static const String version = '1.0.0';
  static const String buildDate = '$dateStr';
  static const String buildTime = '$timeStr';

  static String get fullVersionString => '$fullVersion';
}
''';

  File('lib/version.dart').writeAsStringSync(content);

  final jsonContent = '''{
  "version": "1.0.0",
  "buildDate": "$dateStr",
  "buildTime": "$timeStr",
  "fullVersion": "$fullVersion"
}
''';

  File('web/version.json').writeAsStringSync(jsonContent);
  if (Directory('docs').existsSync()) {
    File('docs/version.json').writeAsStringSync(jsonContent);
  }

  // ignore: avoid_print
  print('Versiyon guncellendi: $fullVersion');
}

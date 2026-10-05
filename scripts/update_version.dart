import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.contains('--post-build')) {
    _handlePostBuild();
    return;
  }
  _handlePreBuild();
}

void _handlePreBuild() {
  final now = DateTime.now();
  final day = now.day.toString().padLeft(2, '0');
  final month = now.month.toString().padLeft(2, '0');
  final year = now.year.toString();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');

  final dateStr = '$day.$month.$year';
  final timeStr = '$hour.$minute';
  final versionKey = '$dateStr-$timeStr';
  final fullVersion = 'Versiyon ($versionKey)';

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

  // Web index ve bootstrap dosyalarındaki versiyon damgasını güncelle
  _updateBuildVersionInFile('web/index.html', versionKey);
  _updateBuildVersionInFile('web/flutter_bootstrap.js', versionKey);

  // ignore: avoid_print
  print('Pre-build versiyon guncellendi: $fullVersion');
}

void _handlePostBuild() {
  final versionFile = File('web/version.json');
  if (!versionFile.existsSync()) {
    // ignore: avoid_print
    print('HATA: web/version.json bulunamadi!');
    return;
  }

  final data = jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
  final dateStr = data['buildDate'] as String;
  final timeStr = data['buildTime'] as String;
  final versionKey = '$dateStr-$timeStr';
  final fullVersion = data['fullVersion'] as String;

  if (Directory('docs').existsSync()) {
    File('docs/version.json').writeAsStringSync(versionFile.readAsStringSync());
    _updateBuildVersionInFile('docs/index.html', versionKey);
    _updateBuildVersionInFile('docs/flutter_bootstrap.js', versionKey);
    _updateFontManifest('docs/assets/FontManifest.json', versionKey);
  }

  if (Directory('build/web').existsSync()) {
    _updateFontManifest('build/web/assets/FontManifest.json', versionKey);
  }

  // ignore: avoid_print
  print('Post-build tamamlandi (Versiyon korundu: $fullVersion)');
}

void _updateBuildVersionInFile(String path, String newVersion) {
  final file = File(path);
  if (!file.existsSync()) return;

  final text = file.readAsStringSync();
  final updated = text.replaceAll(
    RegExp(r"const BUILD_VERSION = '.*?';"),
    "const BUILD_VERSION = '$newVersion';",
  );
  if (updated != text) {
    file.writeAsStringSync(updated);
  }
}

void _updateFontManifest(String path, String versionKey) {
  final file = File(path);
  if (!file.existsSync()) return;

  final text = file.readAsStringSync();
  final updated = text.replaceAllMapped(
    RegExp(r'"asset":\s*"([^"]+?\.(?:otf|ttf))(?:\?v=[^"]*)?"'),
    (match) => '"asset":"${match.group(1)}?v=$versionKey"',
  );
  if (updated != text) {
    file.writeAsStringSync(updated);
  }
}

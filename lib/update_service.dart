import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'version.dart';
import 'utils/app_toast.dart';

@JS('clearCacheAndReload')
external void _jsClearCacheAndReload();

class UpdateService {
  static bool _hasChecked = false;

  /// Önbellek, Service Worker ve çerezleri sıfırlayıp sayfayı sert yeniler.
  static void clearCacheAndReload() {
    if (kIsWeb) {
      try {
        _jsClearCacheAndReload();
      } catch (e) {
        debugPrint('Cache temizleme hatası: $e');
      }
    }
  }

  /// Sunucudaki version.json dosyasını kontrol eder
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateMessage = false,
  }) async {
    if (!kIsWeb) return;
    if (_hasChecked && !showNoUpdateMessage) return;
    _hasChecked = true;

    try {
      final uri = Uri.parse('version.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final remoteVersion = data['fullVersion'] as String? ?? '';
        final localVersion = AppConfig.fullVersionString;

        if (remoteVersion.isNotEmpty && remoteVersion != localVersion) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersion);
          }
        } else if (showNoUpdateMessage && context.mounted) {
          AppToast.show(
            context,
            message: 'Uygulama zaten en güncel sürümde.',
            backgroundColor: const Color(0xFF3A86FF),
            icon: Icons.check_circle_outline,
          );
        }
      }
    } catch (e) {
      debugPrint('Sürüm kontrol hatası: $e');
    }
  }

  static void _showUpdateDialog(BuildContext context, String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF131D36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF3A86FF), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF3A86FF), size: 28),
                SizedBox(width: 12),
                Text(
                  'Yeni Güncelleme Geldi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uygulamaya yeni bir güncelleme geldi.\nEn güncel deneyim için önbellek ve çerezler temizlenerek uygulama yenilenecektir.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mevcut: ${AppConfig.fullVersionString}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yeni: $newVersion',
                        style: const TextStyle(
                          color: Color(0xFF3A86FF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Daha Sonra',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              const _UpdateButton(),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateButton extends StatefulWidget {
  const _UpdateButton();

  @override
  State<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<_UpdateButton> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3A86FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: _isUpdating
          ? null
          : () {
              setState(() => _isUpdating = true);
              UpdateService.clearCacheAndReload();
            },
      icon: _isUpdating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh_rounded),
      label: Text(_isUpdating ? 'Yenileniyor...' : 'Şimdi Güncelle ve Yenile'),
    );
  }
}

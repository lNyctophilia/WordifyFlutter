import 'package:flutter/material.dart';

class InstallPromptPage extends StatelessWidget {
  const InstallPromptPage({super.key});

  Widget _buildPlatformSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> steps,
    String? tip,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: step.startsWith('✓')
                      ? const Color(0xFF3A86FF)
                      : Colors.white70,
                  fontWeight:
                      step.startsWith('✓') ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          if (tip != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A86FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF3A86FF).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tip,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF88B4FF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF3A86FF),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_to_home_screen_rounded,
                      color: Color(0xFF3A86FF),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Uygulamayı Yükleyin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wordify\'a mobilden erişmek için uygulamayı ana ekranınıza eklemeniz gerekmektedir.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _buildPlatformSection(
                      icon: Icons.android_rounded,
                      iconColor: const Color(0xFF3DDC84),
                      title: 'Android (Chrome)',
                      steps: const [
                        '1. Chrome tarayıcısında sağ üstteki üç nokta (⋮) menüsüne dokunun.',
                        '2. Listeden "Uygulamayı yükle" veya "Ana ekrana ekle" seçeneğine basın.',
                        '3. Açılan onay penceresinde "Yükle" seçeneğine tıklayın.',
                        '✓ Artık Wordify ana ekranınızda bağımsız uygulama olarak açılacaktır!',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPlatformSection(
                      icon: Icons.apple_rounded,
                      iconColor: Colors.white,
                      title: 'iOS (Safari)',
                      steps: const [
                        '1. Safari alt menüsündeki Paylaş (⬆) simgesine dokunun.',
                        '2. Açılan menüden "Ana Ekrana Ekle" seçeneğine dokunun.',
                        '3. Sağ üstteki "Ekle" butonuna basarak tamamlayın.',
                        '✓ Artık Wordify ana ekranınızda bağımsız uygulama olarak açılacaktır!',
                      ],
                      tip: '💡 Safari harici tarayıcılarda (Chrome iOS vb.) bu özellik Apple tarafından kısıtlanmıştır, Safari kullanınız.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

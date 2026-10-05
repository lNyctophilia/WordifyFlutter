import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'update_service.dart';
import 'version.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6E8FB0),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor ?? Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white30,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1622),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1622),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          tooltip: 'Geri Dön',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF1E293B),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                if (user != null) ...[
                  _buildSectionHeader('Hesap'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D36),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3A86FF).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF3A86FF),
                          backgroundImage:
                              user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          child: user.photoURL == null
                              ? Text(
                                  (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'Google Kullanıcısı',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user.email ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildSectionHeader('Sistem ve Güncelleme'),
                _buildSettingsCard(
                  icon: Icons.sync_rounded,
                  iconColor: const Color(0xFF3A86FF),
                  title: 'Güncellemeleri Denetle',
                  subtitle: 'Sunucudaki en son sürümü kontrol eder',
                  onTap: () {
                    UpdateService.checkForUpdates(context, showNoUpdateMessage: true);
                  },
                ),
                _buildSettingsCard(
                  icon: Icons.cleaning_services_rounded,
                  iconColor: Colors.orangeAccent,
                  title: 'Çerezleri ve Önbelleği Temizle',
                  subtitle: 'Eski verileri sıfırlar ve sayfayı yeniler',
                  onTap: () {
                    UpdateService.clearCacheAndReload();
                  },
                ),
                if (user != null) ...[
                  _buildSectionHeader('Oturum'),
                  _buildSettingsCard(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.redAccent,
                    title: 'Çıkış Yap',
                    titleColor: Colors.redAccent,
                    subtitle: 'Hesabınızdan güvenle çıkış yapın',
                    onTap: () async {
                      Navigator.pop(context);
                      await AuthService.signOut();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D36),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3A86FF).withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Wordify',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConfig.fullVersionString,
                        style: const TextStyle(
                          color: Color(0xFF6E8FB0),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.06),
                        height: 1,
                        indent: 40,
                        endIndent: 40,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Geliştirici: lNyctophilia',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '© 2026 Tüm Hakları Saklıdır',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

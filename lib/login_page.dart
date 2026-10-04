import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web/web.dart' as web;
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _termsUrl = 'https://sites.google.com/view/wordifyflutter/';

  bool _isLoading = false;
  String? _errorMessage;

  void _openTerms() {
    try {
      final newWindow = web.window.open(_termsUrl, '_blank');
      if (newWindow == null) {
        web.window.location.href = _termsUrl;
      }
    } catch (_) {
      try {
        web.window.location.href = _termsUrl;
      } catch (e) {
        debugPrint('Link açılamadı: $e');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.signInWithGoogle();
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'popup-closed-by-user') {
            _errorMessage = 'Giriş penceresi kapatıldı.';
          } else if (e.code == 'cancelled') {
            _errorMessage = 'Giriş işlemi iptal edildi.';
          } else if (e.code == 'unauthorized-domain') {
            _errorMessage = 'Yetkisiz alan adı: Firebase Console > Auth > Settings > Authorized domains altına lnyctophilia.github.io eklenmelidir.';
          } else if (e.code == 'operation-not-allowed') {
            _errorMessage = 'Google ile giriş Firebase Console üzerinde henüz aktif edilmemiş.';
          } else {
            _errorMessage = 'Giriş başarısız [${e.code}]: ${e.message ?? ''}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Hata: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF3A86FF),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3A86FF).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Wordify',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tek hesapla hem PC hem mobilden anında erişin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Main Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D36),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Giriş Yap veya Kayıt Ol',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                         const SizedBox(height: 24),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Google Sign-In Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F1F1F),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF1F1F1F),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildGoogleLogo(),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Google ile Devam Et',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),


                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom info (tıklanabilir ve geri bildirimli link)
                  SizedBox(
                    width: 340,
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            fontSize: 11,
                            height: 1.5,
                          ) ??
                          const TextStyle(color: Colors.white38, fontSize: 11),
                      textAlign: TextAlign.center,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Giriş yaparak '),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openTerms,
                              borderRadius: BorderRadius.circular(4),
                              splashColor: const Color(0xFF60A5FA).withValues(alpha: 0.25),
                              highlightColor: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                              hoverColor: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Wordify Kullanım Koşulları\'nı',
                                      style: TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF60A5FA),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 11,
                                      color: Color(0xFF60A5FA),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Text('kabul etmiş olursunuz.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // Google Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.785, // -45 deg
      1.57,  // 90 deg
      true,
      paint,
    );

    // Google Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.785, // 45 deg
      1.57, // 90 deg
      true,
      paint,
    );

    // Google Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.355, // 135 deg
      1.57, // 90 deg
      true,
      paint,
    );

    // Google Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.925, // 225 deg
      1.57, // 90 deg
      true,
      paint,
    );

    // Inner White Hole
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, paint);

    // Blue Bar on right
    paint.color = const Color(0xFF4285F4);
    final barRect = Rect.fromLTRB(
      center.dx,
      center.dy - (radius * 0.22),
      w,
      center.dy + (radius * 0.22),
    );
    canvas.drawRect(barRect, paint);

    // Cutout wedge on right top
    paint.color = Colors.white;
    final cutPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(w, center.dy)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(cutPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

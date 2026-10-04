import 'package:web/web.dart' as web;

bool isPWA() {
  final isStandalone = web.window.matchMedia('(display-mode: standalone)').matches;
  return isStandalone;
}

bool isMobileBrowser() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('android') ||
      userAgent.contains('mobile');
}

import 'package:flutter/material.dart';

class AppToast {
  static Color _darken(Color color, [double amount = 0.28]) {
    return Color.lerp(color, Colors.black, amount) ?? color;
  }

  static SnackBar createSnackBar({
    required Widget content,
    Color backgroundColor = const Color(0xFF3A86FF),
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    return SnackBar(
      content: content,
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _darken(backgroundColor),
          width: 1.2,
        ),
      ),
      action: action,
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = const Color(0xFF3A86FF),
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      createSnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }
}

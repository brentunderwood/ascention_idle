import 'package:flutter/material.dart';

/// Simple helper class for showing alerts anywhere in the app.
class AlertHelper {
  /// Show a basic alert dialog with a title and message.
  static Future<void> alertUser(
      BuildContext context,
      String message, {
        String title = 'Notice',
      }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Top-level helper that you can call directly:
///   alert_user(context, "You made ...");
Future<void> alert_user(
    BuildContext context,
    String message, {
      String title = 'Notice',
    }) {
  return AlertHelper.alertUser(context, message, title: title);
}

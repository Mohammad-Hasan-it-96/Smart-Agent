import 'package:flutter/material.dart';

import 'activation_service.dart';

class NotificationActionHandler {
  static Future<void> handle(
    BuildContext context, {
    required String type,
    String? action,
    String? title,
    String? body,
  }) async {
    switch (type) {
      case 'new_plan_activated':
        final activationService = ActivationService();
        bool verified = false;
        try {
          verified = await activationService.recheckActivationStatus();
        } catch (_) {}
        if (!context.mounted) return;
        if (verified) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
              title: const Text(
                'تم تفعيل اشتراكك بنجاح',
                textDirection: TextDirection.rtl,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          return;
        }
        Navigator.of(context).pushNamed('/subscription-plans');
        return;
      case 'still_7_days':
        _showTopBanner(context, title: title, body: body);
        return;
      case 'still_3_days':
        await _showWarningDialog(context, title: title, body: body);
        return;
      case 'still_1_day':
        await _showCriticalAlert(context, title: title, body: body);
        return;
      case 'plan_deactivated':
        final activationService = ActivationService();
        await activationService.saveActivationStatus(false);
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/activation', (route) => false);
        return;
      default:
        if (action == 'open_subscription') {
          Navigator.of(context).pushNamed('/subscription-plans');
        }
    }
  }

  static void _showTopBanner(
    BuildContext context, {
    String? title,
    String? body,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(body ?? 'تبقى 7 أيام على انتهاء الاشتراك.'),
          leading: const Icon(Icons.info_outline),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
  }

  static Future<void> _showWarningDialog(
    BuildContext context, {
    String? title,
    String? body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text(title ?? 'تنبيه الاشتراك'),
        content: Text(body ?? 'باقي 3 أيام على انتهاء الاشتراك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showCriticalAlert(
    BuildContext context, {
    String? title,
    String? body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(title ?? 'تنبيه مهم'),
        content: Text(body ?? 'باقي يوم واحد على انتهاء الاشتراك.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';
import '../utils/whatsapp_helper.dart';

enum ContactMethodType { email, telegram, whatsapp }

class ContactLaunchResult {
  final bool success;
  final String? errorMessage;

  const ContactLaunchResult({
    required this.success,
    this.errorMessage,
  });
}

class ContactLauncherService {
  const ContactLauncherService();

  Future<ContactLaunchResult> launch({
    required ContactMethodType method,
    required SupportContactInfo support,
    required String message,
    String? emailSubject,
  }) async {
    switch (method) {
      case ContactMethodType.email:
        return _launchEmail(
          email: support.email,
          message: message,
          subject: emailSubject ?? 'رسالة من تطبيق المندوب الذكي',
        );
      case ContactMethodType.telegram:
        return _launchTelegram(
          telegramUrl: support.telegram,
          message: message,
        );
      case ContactMethodType.whatsapp:
        return _launchWhatsApp(
          whatsappPhone: support.whatsapp,
          message: message,
        );
    }
  }

  Future<ContactLaunchResult> _launchEmail({
    required String email,
    required String message,
    required String subject,
  }) async {
    try {
      final uri = Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(message)}',
      );
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return const ContactLaunchResult(success: true);
      return const ContactLaunchResult(
        success: false,
        errorMessage: 'تعذر فتح تطبيق البريد الإلكتروني. يرجى المحاولة لاحقاً.',
      );
    } catch (_) {
      return const ContactLaunchResult(
        success: false,
        errorMessage: 'تعذر فتح تطبيق البريد الإلكتروني. يرجى المحاولة لاحقاً.',
      );
    }
  }

  Future<ContactLaunchResult> _launchTelegram({
    required String telegramUrl,
    required String message,
  }) async {
    try {
      final separator = telegramUrl.contains('?') ? '&' : '?';
      final uri = Uri.parse('$telegramUrl$separator'
          'text=${Uri.encodeComponent(message)}');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return const ContactLaunchResult(success: true);
      return const ContactLaunchResult(
        success: false,
        errorMessage: 'تعذر فتح تطبيق تيليجرام. يرجى المحاولة لاحقاً.',
      );
    } catch (_) {
      return const ContactLaunchResult(
        success: false,
        errorMessage: 'تعذر فتح تطبيق تيليجرام. يرجى المحاولة لاحقاً.',
      );
    }
  }

  Future<ContactLaunchResult> _launchWhatsApp({
    required String whatsappPhone,
    required String message,
  }) async {
    final isValid = normalizePhone(whatsappPhone) != null;
    if (!isValid) {
      return const ContactLaunchResult(
        success: false,
        errorMessage: 'رقم واتساب غير صالح. يرجى التحقق من إعدادات الدعم.',
      );
    }

    final opened = await openWhatsAppChat(
      phone: whatsappPhone,
      message: message,
    );
    if (opened) return const ContactLaunchResult(success: true);
    return const ContactLaunchResult(
      success: false,
      errorMessage: 'تعذّر فتح واتساب. تأكد من تثبيت التطبيق أو تحديثه.',
    );
  }

  void showLaunchError(
    BuildContext context, {
    required ContactMethodType method,
    required ContactLaunchResult result,
  }) {
    final message = result.errorMessage ?? 'تعذر فتح طريقة التواصل المختارة.';
    if (method == ContactMethodType.whatsapp &&
        message.contains('تعذّر فتح واتساب')) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('تنبيه', textDirection: TextDirection.rtl),
            ],
          ),
          content: Text(message, textDirection: TextDirection.rtl),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

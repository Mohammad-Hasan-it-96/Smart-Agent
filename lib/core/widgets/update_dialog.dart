import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

void showUpdateDialog(BuildContext context, UpdateInfo info) {
  final hasDownload = info.hasDownloadUrl;
  final hasNotes = info.updateNotes.isNotEmpty;

  final String content;
  if (hasDownload) {
    if (hasNotes) {
      final notes = info.updateNotes.map((note) => '• $note').join('\n');
      content = 'يتوفر إصدار جديد (${info.version})\n\n$notes';
    } else {
      content =
          'يتوفر إصدار جديد (${info.version}). يُنصح بالتحديث للحصول على أفضل أداء.';
    }
  } else {
    content =
        'تم العثور على إصدار جديد (${info.version})، لكن نوع معالج جهازك (${info.abi ?? 'غير معروف'}) غير مدعوم حالياً.\n'
        'يرجى التواصل مع مطور التطبيق للحصول على رابط التحميل المناسب لجهازك.';
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text(
        'يتوفر تحديث جديد',
        textDirection: TextDirection.rtl,
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          textDirection: TextDirection.rtl,
        ),
      ),
      actions: [
        if (hasDownload)
          TextButton(
            child: const Text('لاحقاً'),
            onPressed: () => Navigator.pop(context),
          ),
        ElevatedButton(
          child: Text(hasDownload ? 'تحميل التحديث' : 'حسناً'),
          onPressed: () async {
            Navigator.pop(context);
            if (hasDownload) {
              final rawUrl = info.downloadUrl!.trim();
              final uri = Uri.tryParse(rawUrl) ??
                  Uri.tryParse('https://$rawUrl');
              if (uri != null) {
                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
              }
            }
          },
        ),
      ],
    ),
  );
}

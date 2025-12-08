import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

void showUpdateDialog(BuildContext context, UpdateInfo info) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text(
        "تحديث جديد متاح",
        textDirection: TextDirection.rtl,
      ),
      content: Text(
        "يتوفر إصدار جديد (${info.version}). يُنصح بالتحديث للحصول على أفضل أداء.",
        textDirection: TextDirection.rtl,
      ),
      actions: [
        TextButton(
          child: const Text("لاحقاً"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text("تحميل التحديث"),
          onPressed: () {
            Navigator.pop(context);
            launchUrl(
              Uri.parse(info.downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_export_service.dart';
import 'push_notification_service.dart';

/// Handles incoming .smartagent files from Android intent (file tap, share).
class FileImportHandler {
  FileImportHandler._();
  static final FileImportHandler instance = FileImportHandler._();

  static const MethodChannel _methodChannel =
      MethodChannel('smart_agent/file_import');
  static const EventChannel _eventChannel =
      EventChannel('smart_agent/file_import/events');

  final DataExportService _exportService = DataExportService();

  StreamSubscription? _eventSub;
  bool _initialized = false;

  /// Call once after the MaterialApp widget tree is ready.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Listen for files arriving while the app is running (singleTop re-launch)
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _processIncoming(event);
        }
      },
      onError: (_) {},
    );

    // Check if the app was cold-launched with a file intent
    _checkInitialFile();
  }

  Future<void> _checkInitialFile() async {
    try {
      final result = await _methodChannel.invokeMethod('getInitialFile');
      if (result is Map) {
        _processIncoming(result);
      }
    } catch (_) {
      // Channel not available or no file — ignore.
    }
  }

  void _processIncoming(Map<dynamic, dynamic> data) {
    final bytes = data['bytes'];
    final fileName = data['fileName'] as String? ?? 'unknown';

    if (bytes == null) return;

    Uint8List fileBytes;
    if (bytes is Uint8List) {
      fileBytes = bytes;
    } else if (bytes is List) {
      fileBytes = Uint8List.fromList(bytes.cast<int>());
    } else {
      return;
    }

    // Validate it looks like our JSON
    if (!_isValidSmartAgentFile(fileBytes)) {
      _showError('الملف غير صالح أو تالف. تأكد من أنه ملف بيانات المندوب الذكي.');
      return;
    }

    _showImportConfirmation(fileBytes, fileName);
  }

  bool _isValidSmartAgentFile(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return data.containsKey('companies') && data.containsKey('medicines');
    } catch (_) {
      return false;
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────

  BuildContext? get _ctx => AppNavigatorKey.key.currentContext;

  void _showImportConfirmation(Uint8List bytes, String fileName) {
    final ctx = _ctx;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.file_present_rounded,
                size: 48, color: Colors.blueAccent),
            title: const Text('استيراد بيانات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'هل تريد استيراد البيانات من هذا الملف؟',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file_rounded,
                          size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم إضافة الشركات والأدوية الجديدة فقط.\nالبيانات المتكررة لن تُستورد.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _performImport(bytes);
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('استيراد'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performImport(Uint8List bytes) async {
    final ctx = _ctx;
    if (ctx == null) return;

    // Show loading
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('جارٍ استيراد البيانات...'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _exportService.importData(bytes);

      // Dismiss loading
      if (_ctx != null) Navigator.of(_ctx!).pop();

      _showResultDialog(result);
    } catch (e) {
      // Dismiss loading
      if (_ctx != null) Navigator.of(_ctx!).pop();

      _showError('فشل استيراد البيانات.\nتأكد من أن الملف سليم وغير تالف.');
    }
  }

  void _showResultDialog(ImportResult result) {
    final ctx = _ctx;
    if (ctx == null) return;

    final totalAdded = result.companiesAdded + result.medicinesAdded;
    final icon = totalAdded > 0
        ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48)
        : const Icon(Icons.info_rounded, color: Colors.orange, size: 48);
    final title = totalAdded > 0 ? 'تم الاستيراد بنجاح' : 'لا توجد بيانات جديدة';

    showDialog(
      context: ctx,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: icon,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resultRow(
                  'الشركات', result.companiesAdded, result.companiesSkipped),
              const SizedBox(height: 6),
              _resultRow(
                  'الأدوية', result.medicinesAdded, result.medicinesSkipped),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, int added, int skipped) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('$added أُضيفت'),
        const Text(' ، '),
        Text('$skipped تُخطّيت',
            style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  void _showError(String message) {
    final ctx = _ctx;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon:
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          title: const Text('خطأ في الملف'),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _eventSub?.cancel();
  }
}


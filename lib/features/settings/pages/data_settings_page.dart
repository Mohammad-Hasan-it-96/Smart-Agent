import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/utils/app_logger.dart';
import '../widgets/setting_tile.dart';

class DataSettingsPage extends StatefulWidget {
  const DataSettingsPage({super.key});

  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  final _dataExport = DataExportService();
  final ContactLauncherService _contactLauncher = const ContactLauncherService();
  bool _isExporting = false;
  bool _isImporting = false;

  SupportContactInfo _support = const SupportContactInfo(
    email: SettingsService.defaultSupportEmail,
    telegram: SettingsService.defaultSupportTelegram,
    whatsapp: SettingsService.defaultSupportWhatsapp,
  );

  @override
  void initState() {
    super.initState();
    _loadSupportInfo();
  }

  Future<void> _loadSupportInfo() async {
    try {
      final support = await SettingsService.getSupportInfo();
      if (mounted) setState(() => _support = support);
    } catch (_) {}
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
      appBar: const CustomAppBar(
        title: 'البيانات والملفات',
        showNotifications: false,
        showSettings: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildDataSection(),
          _buildPdfImportSection(isDark),
          _buildShareAppSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return SettingSection(
      title: 'إدارة البيانات',
      icon: Icons.storage_outlined,
      children: [
        SettingTile(
          icon: Icons.cloud_upload_outlined,
          iconColor: Colors.grey,
          title: 'نسخ احتياطي',
          subtitle: 'قريباً — ستتوفر في تحديث قادم',
          enabled: false,
          onTap: () {},
        ),
        SettingTile(
          icon: Icons.file_upload_outlined,
          title: 'تصدير البيانات',
          subtitle: 'حفظ الشركات والأدوية كملف .smartagent',
          trailing: _isExporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isExporting ? null : _exportData,
        ),
        SettingTile(
          icon: Icons.file_download_outlined,
          iconColor: Colors.green,
          title: 'استيراد البيانات',
          subtitle: 'استيراد الشركات والأدوية من ملف .smartagent',
          showDivider: false,
          trailing: _isImporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _isImporting ? null : _importData,
        ),
      ],
    );
  }

  Widget _buildPdfImportSection(bool isDark) {
    const pdfMessage =
        'يمكنك إرسال ملف PDF الخاص بالمستودع عبر واتساب أو تيليجرام، وسيتم تحويله إلى ملف قابل للاستيراد داخل التطبيق (.smartagent) خلال 24-48 ساعة.';
    const pdfWhatsAppMsg =
        'مرحباً، أرغب في تحويل ملف PDF الخاص بالمستودع إلى ملف .smartagent.';

    return SettingSection(
      title: 'استيراد الأدوية من ملف PDF',
      icon: Icons.picture_as_pdf_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.shade900.withValues(alpha: 0.18) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(pdfMessage,
                  style: TextStyle(
                    fontSize: 13.5, height: 1.6,
                    color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingTile(
          icon: Icons.chat_outlined,
          iconColor: Colors.green,
          title: 'إرسال عبر واتساب',
          subtitle: _support.whatsapp,
          onTap: () => _launchSupport(ContactMethodType.whatsapp, pdfWhatsAppMsg),
        ),
        SettingTile(
          icon: Icons.telegram,
          iconColor: const Color(0xFF0088CC),
          title: 'إرسال عبر تيليجرام',
          subtitle: _support.telegram,
          showDivider: false,
          onTap: () => _launchSupport(ContactMethodType.telegram, pdfWhatsAppMsg),
        ),
      ],
    );
  }

  Widget _buildShareAppSection() {
    return SettingSection(
      title: 'مشاركة التطبيق',
      icon: Icons.share_outlined,
      children: [
        SettingTile(
          icon: Icons.people_outline_rounded,
          iconColor: Colors.deepPurple,
          title: 'مشاركة التطبيق مع أصدقائك',
          subtitle: 'شارك رابط التحميل أو رمز QR',
          showDivider: false,
          onTap: _showShareAppDialog,
        ),
      ],
    );
  }

  // ── Actions ──

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await _dataExport.exportData();
      await _dataExport.shareFile(file);
      _snack('تم التصدير بنجاح', bg: Colors.green);
    } catch (e) {
      AppLogger.e('DataSettingsPage', '_exportData failed', e);
      if (e.toString().contains('OFFLINE_LIMIT_EXCEEDED') && mounted) {
        Navigator.of(context).pushReplacementNamed('/offline-limit');
        return;
      }
      _snack('خطأ في التصدير: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    if (_isImporting) return;
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['bin', 'json'],
          dialogTitle: 'اختر ملف .smartagent',
          withData: true,
        );
      } on PlatformException {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          dialogTitle: 'اختر ملف .smartagent',
          withData: true,
        );
      }
      if (result == null || result.files.single.bytes == null) return;

      final fileName = result.files.single.name;
      final bytes = result.files.single.bytes!;

      const allowedExts = {'.smartagent', '.json'};
      final ext = fileName.contains('.') ? '.${fileName.split('.').last.toLowerCase()}' : '';
      if (!allowedExts.contains(ext)) {
        _snack('الملف المحدد غير مدعوم.\nيُرجى اختيار ملف بامتداد .smartagent فقط.', bg: Colors.red);
        return;
      }

      try {
        final decoded = utf8.decode(bytes);
        final data = jsonDecode(decoded) as Map<String, dynamic>;
        if (!data.containsKey('companies') || !data.containsKey('medicines')) {
          _snack('الملف غير صالح: لا يحتوي على بيانات شركات أو أدوية', bg: Colors.red);
          return;
        }
      } catch (e) {
        AppLogger.w('DataSettingsPage', 'import file decode/validation failed', e);
        _snack('الملف تالف أو غير صالح. تأكد من أنه ملف بيانات المندوب الذكي.', bg: Colors.red);
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.file_present_rounded, size: 48, color: Colors.blueAccent),
          title: const Text('استيراد بيانات', textDirection: TextDirection.rtl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تريد استيراد البيانات من هذا الملف؟',
                  textAlign: TextAlign.center, textDirection: TextDirection.rtl),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Flexible(child: Text(fileName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis)),
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
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إضافة الشركات والأدوية الجديدة فقط.\nالبيانات المتكررة لن تُستورد.',
                        style: TextStyle(fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('إلغاء')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('استيراد'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isImporting = true);
      final importResult = await _dataExport.importData(bytes);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم الاستيراد بنجاح', textDirection: TextDirection.rtl),
            ],
          ),
          content: Text(
            'الشركات: ${importResult.companiesAdded} أُضيفت، ${importResult.companiesSkipped} تم تخطيها\n'
            'الأدوية: ${importResult.medicinesAdded} أُضيفت، ${importResult.medicinesSkipped} تم تخطيها',
            textDirection: TextDirection.rtl,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
          ],
        ),
      );
    } catch (e) {
      AppLogger.e('DataSettingsPage', '_importData failed', e);
      _snack('خطأ في الاستيراد: ${e.toString()}', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _launchSupport(ContactMethodType method, String message) async {
    final result = await _contactLauncher.launch(
      method: method,
      support: _support,
      message: message,
    );
    if (!mounted || result.success) return;
    _contactLauncher.showLaunchError(context, method: method, result: result);
  }

  void _showShareAppDialog() {
    const downloadUrl = 'https://harrypotter.foodsalebot.com/api/app-download';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('امسح رمز QR لتنزيل التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87),
              textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: downloadUrl, version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('مشاركة الرابط'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Share.share('حمّل تطبيق Smart Agent من هنا:\n$downloadUrl');
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


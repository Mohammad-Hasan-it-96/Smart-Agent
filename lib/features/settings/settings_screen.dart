import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/data_export_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';
  bool _isLoadingVersion = true;
  final _activationService = ActivationService();
  final _settingsService = SettingsService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _inventoryPhoneController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _pricingFormKey = GlobalKey<FormState>();
  bool _isLoadingAgentData = true;
  bool _isSaving = false;
  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  bool _isLoadingPricingSettings = true;
  bool _isSavingPricing = false;
  bool _hideCarousel = false;
  bool _isLoadingCarouselSetting = true;
  static const String _hideCarouselKey = 'hide_home_carousel';
  final _dataExportService = DataExportService();
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadAgentData();
    _loadPricingSettings();
    _loadCarouselSetting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _inventoryPhoneController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentData() async {
    try {
      final name = await _activationService.getAgentName();
      final phone = await _activationService.getAgentPhone();
      final inventoryPhone = await _settingsService.getInventoryPhone();
      setState(() {
        _nameController.text = name;
        _phoneController.text = phone;
        _inventoryPhoneController.text = inventoryPhone;
        _isLoadingAgentData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAgentData = false;
      });
    }
  }

  Future<void> _saveAgentData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _activationService.saveAgentName(_nameController.text.trim());
      await _activationService.saveAgentPhone(_phoneController.text.trim());
      await _settingsService
          .setInventoryPhone(_inventoryPhoneController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _isLoadingVersion = false;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0+1';
        _isLoadingVersion = false;
      });
    }
  }

  Future<void> _loadPricingSettings() async {
    try {
      final enabled = await _settingsService.isPricingEnabled();
      final mode = await _settingsService.getCurrencyMode();
      final rate = await _settingsService.getExchangeRate();
      setState(() {
        _pricingEnabled = enabled;
        _currencyMode = mode;
        _exchangeRateController.text = rate.toString();
        _isLoadingPricingSettings = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPricingSettings = false;
      });
    }
  }

  Future<void> _loadCarouselSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hideCarousel = prefs.getBool(_hideCarouselKey) ?? false;
        _isLoadingCarouselSetting = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCarouselSetting = false;
      });
    }
  }

  Future<void> _saveCarouselSetting(bool hide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideCarouselKey, hide);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في حفظ الإعداد: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _savePricingSettings() async {
    if (_pricingEnabled && _currencyMode == 'syp') {
      if (_exchangeRateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سعر الصرف'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final rate = double.tryParse(_exchangeRateController.text.trim());
      if (rate == null || rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سعر صرف صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSavingPricing = true;
    });

    try {
      await _settingsService.setPricingEnabled(_pricingEnabled);
      await _settingsService.setCurrencyMode(_currencyMode);
      if (_pricingEnabled && _currencyMode == 'syp') {
        final rate = double.parse(_exchangeRateController.text.trim());
        await _settingsService.setExchangeRate(rate);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPricing = false;
        });
      }
    }
  }

  Future<void> _openSupportEmail() async {
    final email = 'smartAgentAppSupport@gmail.com';
    final emailUri = Uri.parse('mailto:$email');

    try {
      // Try to launch email app directly
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // If launch failed, show email address for manual copy
        _showEmailFallback(email);
      }
    } catch (e) {
      // If error occurs (e.g., no email app), show fallback
      if (mounted) {
        _showEmailFallback(email);
      }
    }
  }

  void _showEmailFallback(String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('البريد الإلكتروني: $email'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'نسخ',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: email));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ البريد الإلكتروني'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  void _checkActivation() {
    // Does nothing for now as requested
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تفعيل هذه الميزة قريباً'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ميزة غير مفعّلة حالياً',
          textDirection: TextDirection.rtl,
        ),
        content: const Text(
          'سيتم تفعيل ميزة النسخ الاحتياطي قريباً في تحديث قادم.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'حسناً',
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final file = await _dataExportService.exportData();
      await _dataExportService.shareFile(file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير البيانات بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Check if it's offline limit exceeded error
      if (e.toString().contains('OFFLINE_LIMIT_EXCEEDED')) {
        Navigator.of(context).pushReplacementNamed('/offline-limit');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التصدير: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _importData() async {
    if (_isImporting) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        return;
      }

      setState(() {
        _isImporting = true;
      });

      // Read file as UTF-8 encoded bytes and decode properly
      final bytes = result.files.single.bytes!;
      final importResult = await _dataExportService.importData(bytes);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'تم الاستيراد بنجاح',
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            'الشركات: ${importResult.companiesAdded} تمت إضافتها، ${importResult.companiesSkipped} تم تخطيها\n'
            'الأدوية: ${importResult.medicinesAdded} تمت إضافتها، ${importResult.medicinesSkipped} تم تخطيها',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'حسناً',
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الاستيراد: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'الإعدادات'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Theme Toggle Section
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : themeProvider.themeMode == ThemeMode.light
                                      ? Icons.light_mode
                                      : Icons.brightness_auto,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'الوضع الداكن / الفاتح',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text('فاتح'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text('داكن'),
                              icon: Icon(Icons.dark_mode),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              label: Text('تلقائي'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                          ],
                          selected: {themeProvider.themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            themeProvider.setThemeMode(newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Carousel Visibility Toggle Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.slideshow,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'إعدادات العرض',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingCarouselSetting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      SwitchListTile(
                        title: const Text(
                          'إظهار الإعلان في الصفحة الرئيسية',
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: const Text(
                          'إظهار أو إخفاء الإعلان في أعلى الصفحة الرئيسية',
                          style: TextStyle(fontSize: 12),
                          textDirection: TextDirection.rtl,
                        ),
                        value: !_hideCarousel,
                        onChanged: (value) {
                          setState(() {
                            _hideCarousel = !value;
                          });
                          _saveCarouselSetting(!value);
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Agent Profile Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بيانات المندوب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingAgentData)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        // Full Name Field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل',
                            hintText: 'أدخل اسمك الكامل',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          textDirection: TextDirection.rtl,
                          textInputAction: TextInputAction.next,
                          enabled: !_isSaving,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال الاسم الكامل';
                            }
                            if (value.trim().length < 3) {
                              return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Phone Number Field
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            hintText: 'أدخل رقم هاتفك',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.rtl,
                          textInputAction: TextInputAction.done,
                          enabled: !_isSaving,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            // Basic phone validation (at least 8 digits)
                            final phoneRegex = RegExp(r'^[0-9]{8,}$');
                            if (!phoneRegex.hasMatch(value
                                .trim()
                                .replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
                              return 'يرجى إدخال رقم هاتف صحيح (8 أرقام على الأقل)';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _saveAgentData(),
                        ),
                        const SizedBox(height: 16),

                        // Inventory WhatsApp Number Field
                        TextFormField(
                          controller: _inventoryPhoneController,
                          decoration: InputDecoration(
                            labelText: 'رقم المستودع (واتساب)',
                            hintText: 'أدخل رقم المستودع لمشاركة الطلبية',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          textInputAction: TextInputAction.done,
                          enabled: !_isSaving,
                          // Optional: don't force the user to fill it
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            // Basic phone validation (at least 8 digits)
                            final phoneRegex = RegExp(r'^[0-9]{8,}$');
                            if (!phoneRegex.hasMatch(
                              text.replaceAll(RegExp(r'[\s\-\(\)\+]'), ''),
                            )) {
                              return 'يرجى إدخال رقم مستودع صحيح (8 أرقام على الأقل)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveAgentData,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'حفظ التعديلات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing Settings Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _pricingFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعدادات الأسعار والفواتير',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingPricingSettings)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        // Enable Pricing Toggle
                        SwitchListTile(
                          title: const Text(
                            'تفعيل الأسعار',
                            textDirection: TextDirection.rtl,
                          ),
                          value: _pricingEnabled,
                          onChanged: (value) {
                            setState(() {
                              _pricingEnabled = value;
                            });
                            if (value) {
                              _savePricingSettings();
                            }
                          },
                        ),
                        if (_pricingEnabled) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'العملة:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<String>(
                            title: const Text(
                              'الدولار \$',
                              textDirection: TextDirection.rtl,
                            ),
                            value: 'usd',
                            groupValue: _currencyMode,
                            onChanged: (value) {
                              setState(() {
                                _currencyMode = value!;
                              });
                              _savePricingSettings();
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text(
                              'الليرة السورية',
                              textDirection: TextDirection.rtl,
                            ),
                            value: 'syp',
                            groupValue: _currencyMode,
                            onChanged: (value) {
                              setState(() {
                                _currencyMode = value!;
                              });
                              _savePricingSettings();
                            },
                          ),
                          if (_currencyMode == 'syp') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _exchangeRateController,
                              decoration: InputDecoration(
                                labelText: 'سعر صرف الدولار',
                                hintText: 'أدخل سعر الصرف',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.currency_exchange),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textDirection: TextDirection.rtl,
                              enabled: !_isSavingPricing,
                              validator: (value) {
                                if (_currencyMode == 'syp' &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'يرجى إدخال سعر الصرف';
                                }
                                if (value != null && value.trim().isNotEmpty) {
                                  final rate = double.tryParse(value.trim());
                                  if (rate == null || rate <= 0) {
                                    return 'يرجى إدخال سعر صرف صحيح';
                                  }
                                }
                                return null;
                              },
                              onChanged: (_) {
                                // Auto-save on change
                                Future.delayed(
                                    const Duration(milliseconds: 500), () {
                                  if (_pricingFormKey.currentState
                                          ?.validate() ??
                                      false) {
                                    _savePricingSettings();
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Re-check Activation Button
            Card(
              elevation: 2,
              child: InkWell(
                onTap: _checkActivation,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.refresh,
                        color: Colors.blue,
                      ),
                      const Expanded(
                        child: Text(
                          'إعادة فحص التفعيل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_back_ios,
                        size: 20,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Backup Section
            Card(
              elevation: 2,
              child: InkWell(
                onTap: _showBackupDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.backup,
                        color: Colors.blue,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'النسخ الاحتياطي',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'حفظ نسخة من البيانات',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_back_ios,
                        size: 20,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Data Sharing Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.share,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'مشاركة البيانات',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Export Button
                    InkWell(
                      onTap: _isExporting ? null : _exportData,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isExporting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(
                                Icons.upload,
                                color: Colors.blue,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'تصدير البيانات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'تصدير الشركات والأدوية لمشاركتها',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Import Button
                    InkWell(
                      onTap: _isImporting ? null : _importData,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isImporting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(
                                Icons.download,
                                color: Colors.green,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'استيراد البيانات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'استيراد الشركات والأدوية من ملف',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // About App Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'حول التطبيق',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.apps, color: Colors.blue),
                      title: const Text(
                        'اسم التطبيق',
                        style: TextStyle(fontWeight: FontWeight.w500),
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: const Text(
                        'المندوب الذكي',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tag, color: Colors.blue),
                      title: const Text(
                        'إصدار التطبيق',
                        style: TextStyle(fontWeight: FontWeight.w500),
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: _isLoadingVersion
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _appVersion,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'مطور التطبيق',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const Text(
                      'تطبيق لإدارة الطلبيات محلياً بدون الحاجة للإنترنت',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Technical Support Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'الدعم الفني',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email, color: Colors.blue),
                      title: const Text(
                        'مراسلة الدعم',
                        style: TextStyle(fontWeight: FontWeight.w500),
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: const Text(
                        'smartAgentAppSupport@gmail.com',
                        style: TextStyle(fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: const Icon(
                        Icons.arrow_back_ios,
                        size: 20,
                        textDirection: TextDirection.rtl,
                      ),
                      onTap: _openSupportEmail,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Update Check Section
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.system_update, color: Colors.blue),
                title: const Text(
                  'التحقق من وجود تحديث',
                  style: TextStyle(fontWeight: FontWeight.w500),
                  textDirection: TextDirection.rtl,
                ),
                trailing: const Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  textDirection: TextDirection.rtl,
                ),
                onTap: () async {
                  try {
                    final pkg = await PackageInfo.fromPlatform();
                    final updateService = UpdateService();
                    final info =
                        await updateService.checkForUpdate(pkg.version);

                    if (mounted) {
                      if (info != null) {
                        showUpdateDialog(context, info);
                      } else {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            content: const Text(
                              "لا يوجد تحديث جديد حالياً.",
                              textDirection: TextDirection.rtl,
                            ),
                            actions: [
                              TextButton(
                                child: const Text("حسناً"),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'حدث خطأ أثناء التحقق من التحديث: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

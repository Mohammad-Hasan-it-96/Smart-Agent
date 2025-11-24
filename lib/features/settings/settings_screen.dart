import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/custom_app_bar.dart';

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
  final _exchangeRateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _pricingFormKey = GlobalKey<FormState>();
  bool _isLoadingAgentData = true;
  bool _isSaving = false;
  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  bool _isLoadingPricingSettings = true;
  bool _isSavingPricing = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadAgentData();
    _loadPricingSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentData() async {
    try {
      final name = await _activationService.getAgentName();
      final phone = await _activationService.getAgentPhone();
      setState(() {
        _nameController.text = name;
        _phoneController.text = phone;
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حول التطبيق',
          style: TextStyle(fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المندوب الذكي',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Text(
                'تطبيق لإدارة الطلبيات محلياً بدون الحاجة للإنترنت',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              const Text(
                'معلومات المطور:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              const Text(
                'للتواصل والدعم الفني',
                style: TextStyle(fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                'البريد الإلكتروني: support@example.com',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                'الهاتف: +966 50 000 0000',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
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
            // App Version Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isLoadingVersion)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        _appVersion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    const Text(
                      'إصدار التطبيق',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
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

            // About App Button
            Card(
              elevation: 2,
              child: InkWell(
                onTap: _showAboutDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                      ),
                      const Expanded(
                        child: Text(
                          'حول التطبيق',
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
            const SizedBox(height: 24),

            // Developer Contact Info Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات التواصل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.email, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'support@example.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '+966 50 000 0000',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

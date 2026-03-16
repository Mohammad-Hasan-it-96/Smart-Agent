import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/medicine.dart';
import '../../core/models/company.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/form_widgets.dart';

class MedicineForm extends StatefulWidget {
  final Medicine? medicine;

  const MedicineForm({super.key, this.medicine});

  @override
  State<MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<MedicineForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceUsdController = TextEditingController();
  final _priceSypController = TextEditingController();
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  final _activationService = ActivationService();
  final _settingsService = SettingsService();
  List<Company> _companies = [];
  int? _selectedCompanyId;
  String? _selectedForm;
  bool _isLoading = false;
  bool _isLoadingCompanies = true;
  String _currencyMode = 'usd';
  double _exchangeRate = 0.0;
  bool _isSyncingPrices = false;

  final List<String> _formOptions = [
    'ظرف',
    'حنجور',
    'تحاميل',
    'علبة',
    'شريط',
    'مرهم',
    'محلول',
  ];

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
    _loadCompanies();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _selectedCompanyId = widget.medicine!.companyId;
      if (widget.medicine!.priceUsd > 0) {
        _priceUsdController.text = widget.medicine!.priceUsd.toString();
      }
      if ((widget.medicine!.priceSyp ?? 0) > 0) {
        _priceSypController.text = widget.medicine!.priceSyp.toString();
      }
      _sourceController.text = widget.medicine!.source ?? '';
      _selectedForm = widget.medicine!.form;
      _notesController.text = widget.medicine!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceUsdController.dispose();
    _priceSypController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingSettings() async {
    final mode = await _settingsService.getCurrencyMode();
    final rate = await _settingsService.getExchangeRate();
    if (!mounted) return;
    setState(() {
      _currencyMode = mode;
      _exchangeRate = rate;
    });
  }

  double? _parseOptionalPrice(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _syncFromUsd(String raw) {
    if (_isSyncingPrices || _exchangeRate <= 0) return;
    final usd = _parseOptionalPrice(raw);
    if (usd == null || usd < 0) return;
    _isSyncingPrices = true;
    _priceSypController.text = _formatPrice(usd * _exchangeRate);
    _isSyncingPrices = false;
  }

  void _syncFromSyp(String raw) {
    if (_isSyncingPrices || _exchangeRate <= 0) return;
    final syp = _parseOptionalPrice(raw);
    if (syp == null || syp < 0) return;
    _isSyncingPrices = true;
    _priceUsdController.text = _formatPrice(syp / _exchangeRate);
    _isSyncingPrices = false;
  }

  Future<void> _loadCompanies() async {
    try {
      final maps = await _dbHelper.query('companies', orderBy: 'name');
      setState(() {
        _companies = maps.map((map) => Company.fromMap(map)).toList();
        _isLoadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCompanies = false;
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الشركة')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      double? priceUsd = _parseOptionalPrice(_priceUsdController.text);
      double? priceSyp = _parseOptionalPrice(_priceSypController.text);

      if (priceUsd != null && priceUsd < 0 || priceSyp != null && priceSyp < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال سعر صحيح')),
        );
        return;
      }

      if (_exchangeRate > 0) {
        // Auto-complete the other currency to keep both prices available.
        if (priceUsd != null && priceSyp == null) {
          priceSyp = priceUsd * _exchangeRate;
        } else if (priceSyp != null && priceUsd == null) {
          priceUsd = priceSyp / _exchangeRate;
        }
      }

      final medicine = Medicine(
        id: widget.medicine?.id,
        name: _nameController.text.trim(),
        companyId: _selectedCompanyId!,
        priceUsd: priceUsd ?? 0.0,
        priceSyp: priceSyp,
        source: _sourceController.text.trim().isEmpty
            ? null
            : _sourceController.text.trim(),
        form: _selectedForm?.trim().isEmpty == true
            ? null
            : _selectedForm?.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (widget.medicine == null) {
        // Check trial mode limits before inserting
        try {
          await _activationService.checkTrialLimitMedicines();
        } on TrialExpiredException catch (e) {
          // Trial expired - redirect to activation
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/activation',
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'انتهت النسخة التجريبية. يرجى التواصل مع المطور لتفعيل التطبيق.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Insert new medicine
        await _dbHelper.insert('medicines', medicine.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الإضافة بنجاح')),
          );
        }
      } else {
        // Update existing medicine (all columns)
        await _dbHelper.update(
          'medicines',
          medicine.toMap(),
          where: 'id = ?',
          whereArgs: [medicine.id],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم التحديث بنجاح')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  // ─── Empty company state ───────────────────────────────────────
  Widget _buildEmptyCompanyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.15)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'لا توجد شركات بعد — أضف شركة للمتابعة',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton.icon(
              onPressed: _showAddCompanySheet,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text(
                'إضافة شركة جديدة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dropdown + add button row ────────────────────────────────
  Widget _buildCompanyDropdownRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedCompanyId,
            decoration: const InputDecoration(
              labelText: 'الشركة',
              prefixIcon: Icon(Icons.business),
            ),
            items: _companies.map((company) {
              return DropdownMenuItem<int>(
                value: company.id,
                child: Text(
                  company.name,
                  textDirection: TextDirection.rtl,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCompanyId = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'يرجى اختيار الشركة';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Tooltip(
            message: 'إضافة شركة جديدة',
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _showAddCompanySheet,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.add_business_rounded,
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Add company bottom sheet ─────────────────────────────────
  void _showAddCompanySheet() {
    final companyNameController = TextEditingController();
    final sheetFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: sheetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.add_business_rounded,
                            color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'إضافة شركة جديدة',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: companyNameController,
                      autofocus: true,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'اسم الشركة',
                        hintText: 'أدخل اسم الشركة',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم الشركة';
                        }
                        // Check for duplicate name
                        final exists = _companies.any((c) =>
                            c.name.trim().toLowerCase() ==
                            value.trim().toLowerCase());
                        if (exists) {
                          return 'هذه الشركة موجودة بالفعل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!sheetFormKey.currentState!.validate()) {
                                  return;
                                }
                                setSheetState(() => isSaving = true);
                                try {
                                  final name =
                                      companyNameController.text.trim();
                                  final newCompany = Company(name: name);
                                  final id = await _dbHelper.insert(
                                      'companies', newCompany.toMap());

                                  // Reload companies and auto-select the new one
                                  final maps = await _dbHelper.query(
                                      'companies',
                                      orderBy: 'name');
                                  if (mounted) {
                                    setState(() {
                                      _companies = maps
                                          .map((m) => Company.fromMap(m))
                                          .toList();
                                      _selectedCompanyId = id;
                                    });
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'تمت إضافة شركة "$name" بنجاح'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'حدث خطأ: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          isSaving ? 'جارٍ الحفظ...' : 'حفظ الشركة',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    return Scaffold(
      appBar: CustomAppBar(
        title: isEdit ? 'تعديل دواء' : 'إضافة دواء',
      ),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormHeader(
                        icon: isEdit
                            ? Icons.edit_rounded
                            : Icons.medication_rounded,
                        title: isEdit ? 'تعديل بيانات الدواء' : 'دواء جديد',
                        subtitle: isEdit
                            ? 'عدّل البيانات ثم اضغط تحديث'
                            : 'أدخل بيانات الدواء لإضافته',
                      ),

                      // ── Basic Info ──
                      FormSection(
                        title: 'المعلومات الأساسية',
                        icon: Icons.info_outline_rounded,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الدواء *',
                              hintText: 'مثال: أموكسيسيللين',
                              prefixIcon: Icon(Icons.medication_rounded),
                            ),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم الدواء';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedForm,
                            decoration: const InputDecoration(
                              labelText: 'الشكل الصيدلاني',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('اختر النوع'),
                              ),
                              ..._formOptions.map((form) {
                                return DropdownMenuItem<String>(
                                  value: form,
                                  child: Text(
                                    form,
                                    textDirection: TextDirection.rtl,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedForm = value;
                              });
                            },
                          ),
                        ],
                      ),

                      // ── Company ──
                      FormSection(
                        title: 'الشركة المصنّعة',
                        icon: Icons.business_rounded,
                        children: [
                          if (_companies.isEmpty)
                            _buildEmptyCompanyState()
                          else
                            _buildCompanyDropdownRow(),
                        ],
                      ),

                      // ── Pricing ──
                      FormSection(
                        title: 'السعر والمصدر',
                        icon: Icons.attach_money_rounded,
                        children: [
                          TextFormField(
                            controller: _priceUsdController,
                            decoration: InputDecoration(
                              labelText: 'سعر الدواء بالدولار (اختياري)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            onChanged: _syncFromUsd,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final price = double.tryParse(value.trim());
                                if (price == null || price < 0) {
                                  return 'يرجى إدخال سعر صحيح';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _priceSypController,
                            decoration: const InputDecoration(
                              labelText: 'سعر الدواء بالليرة السورية (اختياري)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.currency_exchange_rounded),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            onChanged: _syncFromSyp,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final price = double.tryParse(value.trim());
                                if (price == null || price < 0) {
                                  return 'يرجى إدخال سعر صحيح';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _exchangeRate > 0
                                ? 'سعر الصرف الحالي: ${_exchangeRate.toStringAsFixed(2)} (الوضع الحالي: ${_currencyMode == 'syp' ? 'ل.س' : 'USD'})'
                                : 'ملاحظة: أدخل السعرين يدويًا أو حدّد سعر صرف من الإعدادات للتحويل التلقائي.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sourceController,
                            decoration: const InputDecoration(
                              labelText: 'المصدر',
                              hintText:
                                  'أدخل مصدر الدواء (بلد – مستودع – أي نص)',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),

                      // ── Notes ──
                      FormSection(
                        title: 'ملاحظات إضافية',
                        icon: Icons.note_alt_rounded,
                        children: [
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات',
                              hintText: 'أي معلومات إضافية عن الدواء...',
                              prefixIcon: Icon(Icons.note_rounded),
                              alignLabelWithHint: true,
                            ),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _saveMedicine();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      FormSaveButton(
                        isLoading: _isLoading,
                        onPressed: _saveMedicine,
                        label: isEdit ? 'تحديث الدواء' : 'إضافة الدواء',
                        icon: isEdit ? Icons.save_rounded : Icons.add_rounded,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

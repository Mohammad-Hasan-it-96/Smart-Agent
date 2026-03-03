import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/services/activation_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';

class PharmacyForm extends StatefulWidget {
  final Pharmacy? pharmacy;

  const PharmacyForm({super.key, this.pharmacy});

  @override
  State<PharmacyForm> createState() => _PharmacyFormState();
}

class _PharmacyFormState extends State<PharmacyForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  final _activationService = ActivationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pharmacy != null) {
      _nameController.text = widget.pharmacy!.name;
      _addressController.text = widget.pharmacy!.address ?? '';
      _phoneController.text = widget.pharmacy!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePharmacy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pharmacyData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'phone':
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      };

      if (widget.pharmacy == null) {
        // Check trial mode limits before inserting
        try {
          await _activationService.checkTrialLimitPharmacies();
        } on TrialExpiredException {
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

        // Insert new pharmacy
        await _dbHelper.insert('pharmacies', pharmacyData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الإضافة بنجاح')),
          );
        }
      } else {
        // Update existing pharmacy
        await _dbHelper.update(
          'pharmacies',
          pharmacyData,
          where: 'id = ?',
          whereArgs: [widget.pharmacy!.id],
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.pharmacy != null;
    return Scaffold(
      appBar: CustomAppBar(
        title: isEdit ? 'تعديل صيدلية' : 'إضافة صيدلية',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormHeader(
                  icon: isEdit
                      ? Icons.edit_rounded
                      : Icons.local_pharmacy_rounded,
                  title: isEdit ? 'تعديل بيانات الصيدلية' : 'صيدلية جديدة',
                  subtitle: isEdit
                      ? 'عدّل البيانات ثم اضغط تحديث'
                      : 'أدخل بيانات الصيدلية لإضافتها',
                ),

                // ── Basic Info ──
                FormSection(
                  title: 'المعلومات الأساسية',
                  icon: Icons.info_outline_rounded,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصيدلية *',
                        hintText: 'مثال: صيدلية الشفاء',
                        prefixIcon: Icon(Icons.local_pharmacy_rounded),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم الصيدلية';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        hintText: 'المدينة — الشارع — التفاصيل',
                        prefixIcon: Icon(Icons.location_on_rounded),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                    ),
                  ],
                ),

                // ── Contact Info ──
                FormSection(
                  title: 'معلومات التواصل',
                  icon: Icons.phone_rounded,
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        hintText: '09XXXXXXXX',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _savePharmacy();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                FormSaveButton(
                  isLoading: _isLoading,
                  onPressed: _savePharmacy,
                  label: isEdit ? 'تحديث الصيدلية' : 'إضافة الصيدلية',
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

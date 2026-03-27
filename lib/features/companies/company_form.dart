import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/company.dart';
import '../../core/services/activation_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/form_widgets.dart';

class CompanyForm extends StatefulWidget {
  final Company? company;

  const CompanyForm({super.key, this.company});

  @override
  State<CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<CompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  final _activationService = ActivationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.company != null) {
      _nameController.text = widget.company!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final companyData = {
        'name': _nameController.text.trim(),
      };

      if (widget.company == null) {
        // Check trial mode limits before inserting
        try {
          await _activationService.checkTrialLimitCompanies();
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
                    'انتهت النسخة التجريبية. يرجى التواصل مع خدمة العملاء لتفعيل التطبيق.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Insert new company
        await _dbHelper.insert('companies', companyData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الإضافة بنجاح')),
          );
        }
      } else {
        // Update existing company
        await _dbHelper.update(
          'companies',
          companyData,
          where: 'id = ?',
          whereArgs: [widget.company!.id],
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
    final isEdit = widget.company != null;
    return Scaffold(
      appBar: CustomAppBar(
        title: isEdit ? 'تعديل شركة' : 'إضافة شركة',
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
                  icon: isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
                  title: isEdit ? 'تعديل بيانات الشركة' : 'شركة جديدة',
                  subtitle: isEdit
                      ? 'عدّل اسم الشركة ثم اضغط تحديث'
                      : 'أدخل اسم الشركة لإضافتها',
                ),
                FormSection(
                  title: 'معلومات الشركة',
                  icon: Icons.business_rounded,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الشركة *',
                        hintText: 'مثال: شركة فارما',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _saveCompany();
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم الشركة';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSaveButton(
                  isLoading: _isLoading,
                  onPressed: _saveCompany,
                  label: isEdit ? 'تحديث الشركة' : 'إضافة الشركة',
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

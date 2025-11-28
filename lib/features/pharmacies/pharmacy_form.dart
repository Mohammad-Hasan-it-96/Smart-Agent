import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/activation_service.dart';

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
      _addressController.text = widget.pharmacy!.address;
      _phoneController.text = widget.pharmacy!.phone;
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
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (widget.pharmacy == null) {
        // Check trial mode limits before inserting
        final isTrialMode = await _activationService.isTrialMode();
        if (isTrialMode) {
          // Get current pharmacy count
          final db = await _dbHelper.database;
          final result =
              await db.rawQuery('SELECT COUNT(*) as count FROM pharmacies');
          final currentCount = result.first['count'] as int;
          final limit = await _activationService.getTrialPharmaciesLimit();

          if (currentCount >= limit) {
            // Trial expired - disable trial and redirect
            await _activationService.disableTrialMode();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/activation',
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('انتهت النسخة التجريبية – يرجى التواصل مع المطور'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
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
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.pharmacy == null ? 'إضافة صيدلية' : 'تعديل صيدلية',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الصيدلية',
                    prefixIcon: Icon(Icons.local_pharmacy),
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسم الصيدلية';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال العنوان';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _savePharmacy,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.pharmacy == null ? 'إضافة' : 'تحديث',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

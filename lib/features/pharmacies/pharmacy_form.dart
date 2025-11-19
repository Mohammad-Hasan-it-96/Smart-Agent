import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';

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
      appBar: AppBar(
        title: Text(widget.pharmacy == null ? 'إضافة صيدلية' : 'تعديل صيدلية'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الصيدلية',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.local_pharmacy),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال العنوان';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _savePharmacy,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}

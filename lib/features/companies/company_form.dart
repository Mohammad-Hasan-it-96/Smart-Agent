import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/company.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company == null ? 'إضافة شركة' : 'تعديل شركة'),
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
                  labelText: 'اسم الشركة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.business),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الشركة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCompany,
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
                        widget.company == null ? 'إضافة' : 'تحديث',
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

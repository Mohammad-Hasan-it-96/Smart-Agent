import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/medicine.dart';
import '../../core/models/company.dart';

class MedicineForm extends StatefulWidget {
  final Medicine? medicine;

  const MedicineForm({super.key, this.medicine});

  @override
  State<MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<MedicineForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  List<Company> _companies = [];
  int? _selectedCompanyId;
  bool _isLoading = false;
  bool _isLoadingCompanies = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _selectedCompanyId = widget.medicine!.companyId;
      if (widget.medicine!.priceUsd > 0) {
        _priceController.text = widget.medicine!.priceUsd.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
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
      double? priceUsd;
      if (_priceController.text.trim().isNotEmpty) {
        priceUsd = double.tryParse(_priceController.text.trim());
        if (priceUsd == null || priceUsd < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال سعر صحيح')),
          );
          return;
        }
      }

      final medicineData = {
        'name': _nameController.text.trim(),
        'company_id': _selectedCompanyId,
        'price_usd': priceUsd ?? 0.0,
      };

      if (widget.medicine == null) {
        // Insert new medicine
        await _dbHelper.insert('medicines', medicineData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت الإضافة بنجاح')),
          );
        }
      } else {
        // Update existing medicine
        await _dbHelper.update(
          'medicines',
          medicineData,
          where: 'id = ?',
          whereArgs: [widget.medicine!.id],
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
        title: Text(widget.medicine == null ? 'إضافة دواء' : 'تعديل دواء'),
        centerTitle: true,
      ),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الدواء',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.medication),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال اسم الدواء';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int>(
                      value: _selectedCompanyId,
                      decoration: InputDecoration(
                        labelText: 'الشركة',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.business),
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
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'سعر الدواء (بالدولار \$)',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveMedicine,
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
                              widget.medicine == null ? 'إضافة' : 'تحديث',
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

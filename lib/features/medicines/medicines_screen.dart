import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/medicine.dart';
import 'medicine_form.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _filteredMedicines = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _searchController.addListener(_filterMedicines);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Join medicines with companies to get company name
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT 
          medicines.id,
          medicines.name,
          medicines.company_id,
          companies.name as company_name
        FROM medicines
        LEFT JOIN companies ON medicines.company_id = companies.id
        ORDER BY medicines.name
      ''');

      setState(() {
        _medicines = maps;
        _filteredMedicines = maps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMedicines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = _medicines;
      } else {
        _filteredMedicines = _medicines
            .where((medicine) =>
                medicine['name'].toString().toLowerCase().contains(query) ||
                medicine['company_name']
                    .toString()
                    .toLowerCase()
                    .contains(query))
            .toList();
      }
    });
  }

  Future<void> _deleteMedicine(Map<String, dynamic> medicine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${medicine['name']}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.delete(
          'medicines',
          where: 'id = ?',
          whereArgs: [medicine['id']],
        );
        _loadMedicines();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ أثناء الحذف')),
          );
        }
      }
    }
  }

  Future<void> _navigateToForm(Map<String, dynamic>? medicine) async {
    Medicine? medicineModel;
    if (medicine != null) {
      medicineModel = Medicine(
        id: medicine['id'] as int,
        name: medicine['name'] as String,
        companyId: medicine['company_id'] as int,
      );
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineForm(medicine: medicineModel),
      ),
    );

    if (result == true) {
      _loadMedicines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأدوية'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMedicines.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'لا توجد أدوية'
                              : 'لا توجد نتائج',
                          style: const TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final medicine = _filteredMedicines[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                medicine['name'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              subtitle: Text(
                                'الشركة: ${medicine['company_name'] ?? 'غير محدد'}',
                                style: const TextStyle(fontSize: 14),
                                textDirection: TextDirection.rtl,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _navigateToForm(medicine),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteMedicine(medicine),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';
import '../../core/models/company.dart';

class OrderItemData {
  final int medicineId;
  final String medicineName;
  final int companyId;
  final String companyName;
  final int qty;

  OrderItemData({
    required this.medicineId,
    required this.medicineName,
    required this.companyId,
    required this.companyName,
    required this.qty,
  });
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Pharmacy selection
  List<Pharmacy> _pharmacies = [];
  int? _selectedPharmacyId;

  // Medicine search
  final TextEditingController _medicineSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _filteredMedicines = [];
  Map<String, dynamic>? _selectedMedicine;

  // Company selection (filtered by selected medicine)
  List<Company> _availableCompanies = [];
  int? _selectedCompanyId;

  // Quantity
  final TextEditingController _qtyController = TextEditingController();

  // Order items list
  List<OrderItemData> _orderItems = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    _medicineSearchController.addListener(_searchMedicines);
  }

  @override
  void dispose() {
    _medicineSearchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacies() async {
    try {
      final maps = await _dbHelper.query('pharmacies', orderBy: 'name');
      setState(() {
        _pharmacies = maps.map((map) => Pharmacy.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMedicines() async {
    final query = _medicineSearchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredMedicines = [];
        _selectedMedicine = null;
        _availableCompanies = [];
        _selectedCompanyId = null;
      });
      return;
    }

    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT DISTINCT
          medicines.id,
          medicines.name,
          medicines.company_id,
          companies.name as company_name
        FROM medicines
        LEFT JOIN companies ON medicines.company_id = companies.id
        WHERE medicines.name LIKE ?
        ORDER BY medicines.name
      ''', ['%$query%']);

      setState(() {
        _filteredMedicines = maps;
        _selectedMedicine = null;
        _availableCompanies = [];
        _selectedCompanyId = null;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onMedicineSelected(Map<String, dynamic> medicine) {
    setState(() {
      _selectedMedicine = medicine;
      _medicineSearchController.text = medicine['name'] as String;

      // Get all companies that carry this medicine (by name)
      _loadCompaniesForMedicine(medicine['name'] as String);
    });
  }

  Future<void> _loadCompaniesForMedicine(String medicineName) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT DISTINCT
          companies.id,
          companies.name
        FROM medicines
        JOIN companies ON medicines.company_id = companies.id
        WHERE medicines.name = ?
        ORDER BY companies.name
      ''', [medicineName]);

      setState(() {
        _availableCompanies = maps.map((map) => Company.fromMap(map)).toList();
        _selectedCompanyId = null;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _addItemToOrder() {
    if (_selectedPharmacyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصيدلية')),
      );
      return;
    }

    if (_selectedMedicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الدواء')),
      );
      return;
    }

    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الشركة')),
      );
      return;
    }

    final qtyText = _qtyController.text.trim();
    if (qtyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الكمية')),
      );
      return;
    }

    final qty = int.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كمية صحيحة')),
      );
      return;
    }

    // Find the selected company name
    final company = _availableCompanies.firstWhere(
      (c) => c.id == _selectedCompanyId,
    );

    setState(() {
      _orderItems.add(OrderItemData(
        medicineId: _selectedMedicine!['id'] as int,
        medicineName: _selectedMedicine!['name'] as String,
        companyId: _selectedCompanyId!,
        companyName: company.name,
        qty: qty,
      ));
    });

    // Reset form
    _medicineSearchController.clear();
    _qtyController.clear();
    setState(() {
      _selectedMedicine = null;
      _availableCompanies = [];
      _selectedCompanyId = null;
      _filteredMedicines = [];
    });
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  Future<void> _saveOrder() async {
    if (_selectedPharmacyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصيدلية')),
      );
      return;
    }

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة عناصر للطلبية')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Create order
      final now = DateTime.now().toIso8601String();
      final orderData = {
        'pharmacy_id': _selectedPharmacyId,
        'created_at': now,
      };

      final orderId = await _dbHelper.insert('orders', orderData);

      // Create order items
      for (final item in _orderItems) {
        final itemData = {
          'order_id': orderId,
          'medicine_id': item.medicineId,
          'qty': item.qty,
        };
        await _dbHelper.insert('order_items', itemData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الطلبية بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
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
        title: const Text('إنشاء طلبية جديدة'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pharmacy dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedPharmacyId,
                    decoration: InputDecoration(
                      labelText: 'اختر الصيدلية',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.local_pharmacy),
                    ),
                    items: _pharmacies.map((pharmacy) {
                      return DropdownMenuItem<int>(
                        value: pharmacy.id,
                        child: Text(
                          pharmacy.name,
                          textDirection: TextDirection.rtl,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPharmacyId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Medicine search
                  TextField(
                    controller: _medicineSearchController,
                    decoration: InputDecoration(
                      labelText: 'بحث عن دواء',
                      hintText: 'أدخل اسم الدواء',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    textDirection: TextDirection.rtl,
                  ),

                  // Medicine search results
                  if (_filteredMedicines.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final medicine = _filteredMedicines[index];
                          return ListTile(
                            title: Text(
                              medicine['name'] as String,
                              textDirection: TextDirection.rtl,
                            ),
                            subtitle: Text(
                              'الشركة: ${medicine['company_name'] ?? 'غير محدد'}',
                              textDirection: TextDirection.rtl,
                            ),
                            onTap: () => _onMedicineSelected(medicine),
                          );
                        },
                      ),
                    ),

                  // Selected medicine info
                  if (_selectedMedicine != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'الدواء المحدد: ${_selectedMedicine!['name']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ),
                  ],

                  // Company dropdown (only if medicine selected)
                  if (_selectedMedicine != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCompanyId,
                      decoration: InputDecoration(
                        labelText: 'اختر الشركة',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.business),
                      ),
                      items: _availableCompanies.map((company) {
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
                    ),
                  ],

                  // Quantity input
                  if (_selectedCompanyId != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'الكمية',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addItemToOrder,
                      child: const Text('إضافة للطلبية'),
                    ),
                  ],

                  // Order items table
                  if (_orderItems.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'عناصر الطلبية',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1),
                        },
                        children: [
                          // Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                            ),
                            children: const [
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'الدواء',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'الشركة',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'الكمية',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'حذف',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Data rows
                          ...List.generate(_orderItems.length, (index) {
                            final item = _orderItems[index];
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      item.medicineName,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      item.companyName,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      item.qty.toString(),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // Save button
                  if (_orderItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveOrder,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'حفظ الطلبية',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

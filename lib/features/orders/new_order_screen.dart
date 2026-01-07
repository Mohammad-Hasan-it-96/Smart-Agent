import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';
import '../../core/models/company.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/activation_service.dart';
import 'order_details_screen.dart';

class OrderItemData {
  final int medicineId;
  final String medicineName;
  final int companyId;
  final String companyName;
  final int qty;
  final double price;
  final bool isGift;
  final int giftQty;

  OrderItemData({
    required this.medicineId,
    required this.medicineName,
    required this.companyId,
    required this.companyName,
    required this.qty,
    this.price = 0.0,
    this.isGift = false,
    this.giftQty = 0,
  });
}

class MedicineWithCompanies {
  final String name;
  final int medicineId;
  final List<String> companyNames;

  MedicineWithCompanies({
    required this.name,
    required this.medicineId,
    required this.companyNames,
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
  List<MedicineWithCompanies> _medicinesWithCompanies = [];

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

  Future<void> _showAddPharmacyDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إضافة صيدلية جديدة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
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
                  controller: addressController,
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
                  controller: phoneController,
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                          });

                          try {
                            // Check trial mode limits before inserting
                            final activationService = ActivationService();
                            final isTrialMode =
                                await activationService.isTrialMode();
                            if (isTrialMode) {
                              // Get current pharmacy count
                              final db = await _dbHelper.database;
                              final result = await db.rawQuery(
                                  'SELECT COUNT(*) as count FROM pharmacies');
                              final currentCount = result.first['count'] as int;
                              final limit = await activationService
                                  .getTrialPharmaciesLimit();

                              if (currentCount >= limit) {
                                // Trial expired - disable trial and redirect
                                await activationService.disableTrialMode();
                                if (mounted) {
                                  Navigator.of(context).pop(); // Close dialog
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/activation',
                                    (route) => false,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'انتهت النسخة التجريبية – يرجى التواصل مع المطور'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 5),
                                    ),
                                  );
                                }
                                return;
                              }
                            }

                            final pharmacyData = {
                              'name': nameController.text.trim(),
                              'address': addressController.text.trim(),
                              'phone': phoneController.text.trim(),
                            };

                            final newPharmacyId = await _dbHelper.insert(
                                'pharmacies', pharmacyData);

                            // Reload pharmacies
                            await _loadPharmacies();

                            // Auto-select the new pharmacy
                            setState(() {
                              _selectedPharmacyId = newPharmacyId;
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت إضافة الصيدلية بنجاح'),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSaving = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ: ${e.toString()}'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'حفظ',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchMedicines() async {
    final query = _medicineSearchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _medicinesWithCompanies = [];
      });
      return;
    }

    try {
      final db = await _dbHelper.database;

      // Get unique medicines with all their companies in one query
      // Group by name only to ensure each medicine appears once
      final medicineMaps = await db.rawQuery('''
        SELECT 
          MIN(medicines.id) as id,
          medicines.name,
          GROUP_CONCAT(DISTINCT companies.name) as company_names
        FROM medicines
        LEFT JOIN companies ON medicines.company_id = companies.id
        WHERE medicines.name LIKE ?
        GROUP BY medicines.name
        ORDER BY medicines.name
      ''', ['%$query%']);

      // Build medicines list with companies
      List<MedicineWithCompanies> medicinesList = [];

      for (final medicine in medicineMaps) {
        final medicineName = medicine['name'] as String;
        final medicineId = medicine['id'] as int;
        final companyNamesStr = medicine['company_names'] as String? ?? '';

        // Split company names and filter out empty strings
        // GROUP_CONCAT uses comma as default separator
        final companyNames = companyNamesStr
            .split(',')
            .where((name) => name.trim().isNotEmpty)
            .map((name) => name.trim())
            .toList();

        // If no companies found, add a placeholder
        if (companyNames.isEmpty) {
          companyNames.add('غير محدد');
        }

        medicinesList.add(MedicineWithCompanies(
          name: medicineName,
          medicineId: medicineId,
          companyNames: companyNames,
        ));
      }

      setState(() {
        _medicinesWithCompanies = medicinesList;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onMedicineSelected(MedicineWithCompanies medicine) {
    // Debug print
    print("Selected: ${medicine.name}");

    // Clear search field and results immediately
    _medicineSearchController.clear();
    setState(() {
      _medicinesWithCompanies = [];
    });

    // Load companies and show dialog
    _loadCompaniesForMedicineAndShowDialog(medicine);
  }

  Future<void> _loadCompaniesForMedicineAndShowDialog(
      MedicineWithCompanies medicine) async {
    try {
      final db = await _dbHelper.database;

      // Get medicine with price
      final medicineData = await db.rawQuery('''
        SELECT id, name, price_usd
        FROM medicines
        WHERE id = ?
      ''', [medicine.medicineId]);

      if (medicineData.isEmpty) return;

      final medicineInfo = medicineData.first;

      // Get companies for this medicine
      final maps = await db.rawQuery('''
        SELECT DISTINCT
          companies.id,
          companies.name
        FROM medicines
        JOIN companies ON medicines.company_id = companies.id
        WHERE medicines.name = ? AND medicines.id = ?
        ORDER BY companies.name
      ''', [medicine.name, medicine.medicineId]);

      final companies = maps.map((map) => Company.fromMap(map)).toList();

      if (!mounted) return;

      // Create medicine map for dialog with price
      final medicineMap = {
        'id': medicineInfo['id'] as int,
        'name': medicineInfo['name'] as String,
        'price_usd': medicineInfo['price_usd'] as num?,
      };

      // Show dialog with companies and quantity input
      await _showMedicineSelectionDialog(medicineMap, companies);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showMedicineSelectionDialog(
    Map<String, dynamic> medicine,
    List<Company> companies,
  ) async {
    if (companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد شركات لهذا الدواء')),
      );
      return;
    }

    int? selectedCompanyId;
    final qtyController = TextEditingController();
    final giftQtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isGift = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  medicine['name'] as String,
                  style: const TextStyle(fontSize: 18),
                  textDirection: TextDirection.rtl,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر الشركة:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedCompanyId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    items: companies.map((company) {
                      return DropdownMenuItem<int>(
                        value: company.id,
                        child: Text(
                          company.name,
                          textDirection: TextDirection.rtl,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCompanyId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'يرجى اختيار الشركة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الكمية:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.rtl,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      final qty = int.tryParse(value.trim());
                      if (qty == null || qty <= 0) {
                        return 'يرجى إدخال كمية صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: isGift,
                      onChanged: (value) {
                        setDialogState(() {
                          isGift = value ?? false;
                          if (!isGift) {
                            giftQtyController.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'هدية',
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: const Text(
                        'لا يتم احتساب سعر هذا العنصر في المجموع',
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                  if (isGift) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'كمية الهدية:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: giftQtyController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.card_giftcard),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      validator: (value) {
                        if (!isGift) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال كمية الهدية';
                        }
                        final qty = int.tryParse(value.trim());
                        if (qty == null || qty <= 0) {
                          return 'يرجى إدخال كمية هدية صحيحة';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                if (selectedCompanyId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الشركة')),
                  );
                  return;
                }

                final qtyText = qtyController.text.trim();
                final qty = int.tryParse(qtyText);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال كمية صحيحة')),
                  );
                  return;
                }

                int giftQty = 0;
                if (isGift) {
                  final giftQtyText = giftQtyController.text.trim();
                  giftQty = int.tryParse(giftQtyText) ?? 0;
                  if (giftQty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال كمية هدية صحيحة')),
                    );
                    return;
                  }
                }

                // Check if pharmacy is selected
                if (_selectedPharmacyId == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الصيدلية أولاً')),
                  );
                  return;
                }

                // Find company name
                final company = companies.firstWhere(
                  (c) => c.id == selectedCompanyId,
                );

                // Get price directly from medicine record (always in USD)
                final medicinePriceUsd =
                    (medicine['price_usd'] as num?)?.toDouble() ?? 0.0;

                // Add to order list
                setState(() {
                  _orderItems.add(
                    OrderItemData(
                      medicineId: medicine['id'] as int,
                      medicineName: medicine['name'] as String,
                      companyId: selectedCompanyId!,
                      companyName: company.name,
                      qty: qty,
                      // If item is a gift, store price as 0 (will not affect totals)
                      price: medicinePriceUsd,
                      isGift: false,
                      giftQty: giftQty,
                    ),
                  );
                });

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تمت إضافة ${medicine['name']} للطلبية'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  Future<void> _saveOrder() async {
    // Validation: Check pharmacy
    if (_selectedPharmacyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصيدلية')),
      );
      return;
    }

    // Validation: Check at least one item
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة عنصر واحد على الأقل للطلبية'),
          backgroundColor: Colors.red,
        ),
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
          'price': item.price,
          'is_gift': item.isGift ? 1 : 0,
          'gift_qty': item.giftQty,
        };
        await _dbHelper.insert('order_items', itemData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الطلبية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to Order Details Screen
        Navigator.pushReplacement(
          context,
          SlidePageRoute(
            page: OrderDetailsScreen(orderId: orderId),
            direction: SlideDirection.rightToLeft,
          ),
        );
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'إنشاء طلبية جديدة'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 1: Pharmacy Selection
                          _buildSectionHeader(
                              '1', 'اختيار الصيدلية', Icons.local_pharmacy),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _selectedPharmacyId,
                                      decoration: const InputDecoration(
                                        labelText: 'اختر الصيدلية',
                                        prefixIcon: Icon(Icons.local_pharmacy),
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
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _showAddPharmacyDialog,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(thickness: 2),
                          const SizedBox(height: 24),

                          // Section 2: Medicine Search + Selection
                          _buildSectionHeader(
                              '2', 'بحث وإضافة الأدوية', Icons.medication),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _medicineSearchController,
                                    decoration: const InputDecoration(
                                      labelText: 'بحث عن دواء',
                                      hintText: 'أدخل اسم الدواء',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  // Medicine search results
                                  if (_medicinesWithCompanies.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                        color: theme.colorScheme.surfaceVariant,
                                      ),
                                      constraints:
                                          const BoxConstraints(maxHeight: 200),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount:
                                              _medicinesWithCompanies.length,
                                          separatorBuilder: (context, index) =>
                                              Divider(
                                            height: 1,
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.2),
                                          ),
                                          itemBuilder: (context, index) {
                                            final medicine =
                                                _medicinesWithCompanies[index];
                                            return InkWell(
                                              onTap: () {
                                                _onMedicineSelected(medicine);
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 12.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            medicine.name,
                                                            style: theme
                                                                .textTheme
                                                                .bodyLarge
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                            ),
                                                            textDirection:
                                                                TextDirection
                                                                    .rtl,
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Text(
                                                            'الشركات: ${medicine.companyNames.join(' | ')}',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7),
                                                            ),
                                                            textDirection:
                                                                TextDirection
                                                                    .rtl,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons
                                                          .arrow_back_ios_new_rounded,
                                                      size: 16,
                                                      color: theme
                                                          .colorScheme.onSurface
                                                          .withValues(
                                                              alpha: 0.6),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(thickness: 2),
                          const SizedBox(height: 24),

                          // Section 3: Current Order Items
                          _buildSectionHeader(
                              '3', 'عناصر الطلبية', Icons.shopping_cart),
                          const SizedBox(height: 12),
                          if (_orderItems.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا توجد عناصر في الطلبية',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'ابحث عن دواء وأضفه للطلبية',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_orderItems.length} عنصر',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                        const Text(
                                          'اسحب لحذف العنصر',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _orderItems.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _orderItems[index];
                                      return Dismissible(
                                        key: Key('order_item_$index'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding:
                                              const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        onDismissed: (direction) {
                                          _removeItem(index);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'تم حذف ${item.medicineName}'),
                                              action: SnackBarAction(
                                                label: 'تراجع',
                                                onPressed: () {
                                                  setState(() {
                                                    _orderItems.insert(
                                                        index, item);
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                item.qty.toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            item.medicineName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                item.companyName,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                textDirection:
                                                    TextDirection.rtl,
                                              ),
                                              if (item.giftQty > 0)
                                                Text(
                                                  'هدية: ${item.giftQty}',
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textDirection:
                                                      TextDirection.rtl,
                                                ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  // Section 4: Save Button (Fixed at bottom)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: FilledButton(
                        onPressed: _isSaving || _orderItems.isEmpty
                            ? null
                            : _saveOrder,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor:
                              theme.colorScheme.surfaceVariant,
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save),
                                  const SizedBox(width: 8),
                                  Text(
                                    'حفظ الطلبية ${_orderItems.isEmpty ? '' : '(${_orderItems.length})'}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String number, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

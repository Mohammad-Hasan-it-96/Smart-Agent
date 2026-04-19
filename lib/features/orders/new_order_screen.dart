import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/pharmacy.dart';
import '../../core/models/company.dart';
import '../../core/models/gift.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/utils/phone_validator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/invoice_number_service.dart';
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

class GiftOrderItemData {
  final int giftId;
  final String giftName;
  final String? giftNotes;
  final int qty;

  GiftOrderItemData({
    required this.giftId,
    required this.giftName,
    this.giftNotes,
    required this.qty,
  });
}

class NewOrderScreen extends StatefulWidget {
  /// When non-null, the screen opens in edit mode for the given order ID.
  final int? editOrderId;

  const NewOrderScreen({super.key, this.editOrderId});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SettingsService _settingsService = getIt<SettingsService>();

  // Pharmacy selection
  List<Pharmacy> _pharmacies = [];
  int? _selectedPharmacyId;

  // Medicine search
  final TextEditingController _medicineSearchController =
      TextEditingController();
  List<MedicineWithCompanies> _medicinesWithCompanies = [];

  // Order items list
  final List<OrderItemData> _orderItems = [];
  // Gift order items list
  final List<GiftOrderItemData> _giftItems = [];

  // Gift search
  final TextEditingController _giftSearchController = TextEditingController();
  List<Gift> _giftsSearchResults = [];
  bool _hasGiftSearched = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String _currencyMode = 'usd';
  // Tracks whether a medicine search has been executed at least once
  // (used to distinguish "not searched yet" from "searched but no results").
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
    _loadPharmacies();
    _medicineSearchController.addListener(_searchMedicines);
    _giftSearchController.addListener(_searchGifts);
    if (widget.editOrderId != null) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadPricingSettings() async {
    final mode = await _settingsService.getCurrencyMode();
    if (!mounted) return;
    setState(() {
      _currencyMode = mode;
    });
  }

  @override
  void dispose() {
    _medicineSearchController.dispose();
    _giftSearchController.dispose();
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

  /// Loads the existing order's pharmacy and items into the form (edit mode).
  Future<void> _loadExistingOrder() async {
    try {
      final db = await _dbHelper.database;

      // Load the order's selected pharmacy
      final orderRows = await db.rawQuery(
        'SELECT pharmacy_id FROM orders WHERE id = ?',
        [widget.editOrderId],
      );
      if (orderRows.isNotEmpty && mounted) {
        setState(() {
          _selectedPharmacyId =
              (orderRows.first['pharmacy_id'] as num?)?.toInt();
        });
      }

      // Load existing order items with medicine + company details
      final itemRows = await db.rawQuery('''
        SELECT
          oi.medicine_id,
          m.name        AS medicine_name,
          m.company_id,
          c.name        AS company_name,
          oi.qty,
          COALESCE(oi.price, 0.0) AS price,
          oi.is_gift,
          oi.gift_qty
        FROM order_items oi
        LEFT JOIN medicines  m ON oi.medicine_id = m.id
        LEFT JOIN companies  c ON m.company_id   = c.id
        WHERE oi.order_id = ?
      ''', [widget.editOrderId]);

      if (!mounted) return;
      setState(() {
        _orderItems
          ..clear()
          ..addAll(itemRows.map((row) => OrderItemData(
                medicineId:   (row['medicine_id']  as num).toInt(),
                medicineName: (row['medicine_name'] as String?) ?? 'غير معروف',
                companyId:    (row['company_id']   as num?)?.toInt() ?? 0,
                companyName:  (row['company_name'] as String?) ?? 'غير معروف',
                qty:          (row['qty']          as num?)?.toInt() ?? 0,
                price:        (row['price']        as num?)?.toDouble() ?? 0.0,
                isGift:       (row['is_gift']      as int?) == 1,
                giftQty:      (row['gift_qty']     as num?)?.toInt() ?? 0,
              )));
      });

      // Load existing gift items
      final giftRows = await db.rawQuery('''
        SELECT ogi.gift_id, g.name AS gift_name, g.notes AS gift_notes, ogi.qty
        FROM order_gift_items ogi
        LEFT JOIN gifts g ON ogi.gift_id = g.id
        WHERE ogi.order_id = ?
      ''', [widget.editOrderId]);

      if (!mounted) return;
      setState(() {
        _giftItems
          ..clear()
          ..addAll(giftRows.map((row) => GiftOrderItemData(
                giftId:    (row['gift_id']    as num).toInt(),
                giftName:  (row['gift_name']  as String?) ?? 'غير معروف',
                giftNotes: row['gift_notes']  as String?,
                qty:       (row['qty']        as num?)?.toInt() ?? 1,
              )));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات الطلبية: $e')),
        );
      }
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
                  // Optional
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '09XXXXXXXX',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  validator: (v) => validatePhone(v, required: false),
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
                            final activationService = getIt<ActivationService>();
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
                                          'انتهت النسخة التجريبية – يرجى التواصل مع خدمة العملاء'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 5),
                                    ),
                                  );
                                }
                                return;
                              }
                            }

                            final address = addressController.text.trim();
                            final phone = phoneController.text.trim();
                            final pharmacyData = {
                              'name': nameController.text.trim(),
                              'address': address.isEmpty ? null : address,
                              'phone': phone.isEmpty ? null : phone,
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

  Future<void> _searchGifts() async {
    final query = _giftSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _giftsSearchResults = [];
        _hasGiftSearched = false;
      });
      return;
    }
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'gifts',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'name ASC',
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _giftsSearchResults = rows.map(Gift.fromMap).toList();
        _hasGiftSearched = true;
      });
    } catch (_) {}
  }

  void _onGiftSelected(Gift gift) {
    _giftSearchController.clear();
    setState(() {
      _giftsSearchResults = [];
      _hasGiftSearched = false;
    });
    _showGiftQtyDialog(gift);
  }

  Future<void> _showGiftQtyDialog(Gift gift) async {
    int qty = 1;
    final controller = TextEditingController(text: '1');

    int parseQty(String text) {
      final v = int.tryParse(text.trim()) ?? 1;
      return v < 1 ? 1 : v;
    }

    void syncCtrl(int value) {
      controller.value = TextEditingValue(
        text: value.toString(),
        selection: TextSelection.collapsed(offset: value.toString().length),
      );
    }

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    gift.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: _QuantityStepperField(
              label: 'الكمية',
              icon: Icons.card_giftcard_outlined,
              controller: controller,
              onIncrement: () => setD(() { qty += 1; syncCtrl(qty); }),
              onDecrement: () => setD(() { if (qty > 1) qty -= 1; syncCtrl(qty); }),
              onManualChanged: (v) => setD(() => qty = parseQty(v)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('إضافة'),
                onPressed: () {
                  qty = parseQty(controller.text);
                  setState(() {
                    // If already added, update qty
                    final idx = _giftItems.indexWhere((g) => g.giftId == gift.id);
                    if (idx >= 0) {
                      _giftItems[idx] = GiftOrderItemData(
                        giftId: gift.id!,
                        giftName: gift.name,
                        giftNotes: gift.notes,
                        qty: _giftItems[idx].qty + qty,
                      );
                    } else {
                      _giftItems.add(GiftOrderItemData(
                        giftId: gift.id!,
                        giftName: gift.name,
                        giftNotes: gift.notes,
                        qty: qty,
                      ));
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تمت إضافة ${gift.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _removeGiftItem(int index) {
    setState(() => _giftItems.removeAt(index));
  }

  Future<void> _editGiftItemQty(int index) async {
    final item = _giftItems[index];
    int qty = item.qty;
    final controller = TextEditingController(text: qty.toString());

    int parseQty(String text) {
      final v = int.tryParse(text.trim()) ?? 1;
      return v < 1 ? 1 : v;
    }

    void syncCtrl(int value) {
      controller.value = TextEditingValue(
        text: value.toString(),
        selection: TextSelection.collapsed(offset: value.toString().length),
      );
    }

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(item.giftName,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            content: _QuantityStepperField(
              label: 'الكمية',
              icon: Icons.card_giftcard_outlined,
              controller: controller,
              onIncrement: () => setD(() { qty += 1; syncCtrl(qty); }),
              onDecrement: () => setD(() { if (qty > 1) qty -= 1; syncCtrl(qty); }),
              onManualChanged: (v) => setD(() => qty = parseQty(v)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('تحديث'),
                onPressed: () {
                  qty = parseQty(controller.text);
                  setState(() {
                    _giftItems[index] = GiftOrderItemData(
                      giftId: item.giftId,
                      giftName: item.giftName,
                      giftNotes: item.giftNotes,
                      qty: qty,
                    );
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _searchMedicines() async {
    final query = _medicineSearchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _medicinesWithCompanies = [];
        _hasSearched = false;
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
        _hasSearched = true;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onMedicineSelected(MedicineWithCompanies medicine) {

    // Clear search field and results immediately
    _medicineSearchController.clear();
    setState(() {
      _medicinesWithCompanies = [];
      _hasSearched = false;
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
        SELECT id, name, price_usd, price_syp
        FROM medicines
        WHERE id = ?
      ''', [medicine.medicineId]);

      if (medicineData.isEmpty) return;

      final medicineInfo = medicineData.first;

      // Get companies for this medicine (by name, to find ALL companies
      // across all rows that share the same medicine name)
      final maps = await db.rawQuery('''
        SELECT DISTINCT
          companies.id,
          companies.name
        FROM medicines
        JOIN companies ON medicines.company_id = companies.id
        WHERE medicines.name = ?
        ORDER BY companies.name
      ''', [medicine.name]);

      final companies = maps.map((map) => Company.fromMap(map)).toList();

      if (!mounted) return;

      // Create medicine map for dialog with price
      final medicineMap = {
        'id': medicineInfo['id'] as int,
        'name': medicineInfo['name'] as String,
        'price_usd': medicineInfo['price_usd'] as num?,
        'price_syp': medicineInfo['price_syp'] as num?,
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

    int? selectedCompanyId = companies.first.id;
    int paidQty = 1;
    int giftQty = 1;
    bool hasGift = false;

    final paidQtyController = TextEditingController(text: '1');
    final giftQtyController = TextEditingController(text: '1');

    int parseQty(String text) {
      final value = int.tryParse(text.trim()) ?? 0;
      return value < 0 ? 0 : value;
    }

    void syncController(TextEditingController controller, int value) {
      controller.value = TextEditingValue(
        text: value.toString(),
        selection: TextSelection.collapsed(offset: value.toString().length),
      );
    }

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        medicine['name'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companies.length > 1
                            ? 'اختر الشركة والكمية بسرعة'
                            : 'تم اختيار الشركة تلقائياً',
                        style: Theme.of(context).textTheme.bodySmall,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (companies.length > 1)
                    DropdownButtonFormField<int>(
                      value: selectedCompanyId,
                      decoration: InputDecoration(
                        labelText: 'الشركة',
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
                        if (value == null) return;
                        setDialogState(() {
                          selectedCompanyId = value;
                        });
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              companies.first.name,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  _QuantityStepperField(
                    label: 'الكمية',
                    icon: Icons.shopping_bag_outlined,
                    controller: paidQtyController,
                    onIncrement: () {
                      setDialogState(() {
                        paidQty += 1;
                        syncController(paidQtyController, paidQty);
                      });
                    },
                    onDecrement: () {
                      setDialogState(() {
                        if (paidQty > 0) paidQty -= 1;
                        syncController(paidQtyController, paidQty);
                      });
                    },
                    onManualChanged: (value) {
                      setDialogState(() {
                        paidQty = parseQty(value);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: hasGift,
                      onChanged: (value) {
                        setDialogState(() {
                          hasGift = value ?? false;
                          if (!hasGift) {
                            giftQty = 0;
                            syncController(giftQtyController, giftQty);
                          } else if (giftQty == 0) {
                            giftQty = 1;
                            syncController(giftQtyController, giftQty);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'يوجد هدية',
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: const Text(
                        'الهدية لا تؤثر على إجمالي السعر',
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasGift)
                    _QuantityStepperField(
                      label: 'الهدية',
                      icon: Icons.card_giftcard,
                      controller: giftQtyController,
                      onIncrement: () {
                        setDialogState(() {
                          giftQty += 1;
                          syncController(giftQtyController, giftQty);
                        });
                      },
                      onDecrement: () {
                        setDialogState(() {
                          if (giftQty > 0) giftQty -= 1;
                          syncController(giftQtyController, giftQty);
                        });
                      },
                      onManualChanged: (value) {
                        setDialogState(() {
                          giftQty = parseQty(value);
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('إضافة للطلبية'),
                onPressed: () {
                  paidQty = parseQty(paidQtyController.text);
                  giftQty = hasGift ? parseQty(giftQtyController.text) : 0;

                  if (paidQty == 0 && giftQty == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'يرجى إدخال كمية أو تفعيل الهدية ثم تحديد كميتها',
                        ),
                      ),
                    );
                    return;
                  }

                  // Check if pharmacy is selected
                  if (_selectedPharmacyId == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار الصيدلية أولاً')),
                    );
                    return;
                  }

                  if (selectedCompanyId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار الشركة')),
                    );
                    return;
                  }

                  final company = companies.firstWhere(
                    (c) => c.id == selectedCompanyId,
                  );

                  final medicinePriceUsd =
                      (medicine['price_usd'] as num?)?.toDouble();
                  final medicinePriceSyp =
                      (medicine['price_syp'] as num?)?.toDouble();

                  double selectedUnitPrice = 0.0;
                  if (_currencyMode == 'syp') {
                    if ((medicinePriceSyp ?? 0) > 0) {
                      selectedUnitPrice = medicinePriceSyp!;
                    } else if ((medicinePriceUsd ?? 0) > 0) {
                      selectedUnitPrice = medicinePriceUsd!;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'سعر الليرة غير محدد لهذا الدواء، تم استخدام سعر الدولار كبديل.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    if ((medicinePriceUsd ?? 0) > 0) {
                      selectedUnitPrice = medicinePriceUsd!;
                    } else if ((medicinePriceSyp ?? 0) > 0) {
                      selectedUnitPrice = medicinePriceSyp!;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'سعر الدولار غير محدد لهذا الدواء، تم استخدام سعر الليرة كبديل.',
                            ),
                          ),
                        );
                      }
                    }
                  }

                  // Gift-only rows are marked with isGift=true; mixed rows stay paid.
                  final isGiftOnly = paidQty == 0 && giftQty > 0;

                  setState(() {
                    _orderItems.add(
                      OrderItemData(
                        medicineId: medicine['id'] as int,
                        medicineName: medicine['name'] as String,
                        companyId: selectedCompanyId!,
                        companyName: company.name,
                        qty: paidQty,
                        price: selectedUnitPrice,
                        isGift: isGiftOnly,
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
              ),
            ],
          ),
        ),
      );
    } finally {
      paidQtyController.dispose();
      giftQtyController.dispose();
    }
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  /// Opens an edit dialog for the quantity/gift of the item at [index].
  /// Reuses [_QuantityStepperField] so the UX is identical to the add flow.
  Future<void> _editItemQuantity(int index) async {
    final item = _orderItems[index];
    int paidQty = item.qty;
    int giftQty = item.giftQty;
    bool hasGift = giftQty > 0;

    final paidQtyController =
        TextEditingController(text: paidQty.toString());
    final giftQtyController =
        TextEditingController(text: giftQty.toString());

    int parseQty(String text) {
      final v = int.tryParse(text.trim()) ?? 0;
      return v < 0 ? 0 : v;
    }

    void syncController(TextEditingController ctrl, int value) {
      ctrl.value = TextEditingValue(
        text: value.toString(),
        selection:
            TextSelection.collapsed(offset: value.toString().length),
      );
    }

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.medicineName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.companyName,
                        style: Theme.of(context).textTheme.bodySmall,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuantityStepperField(
                    label: 'الكمية',
                    icon: Icons.shopping_bag_outlined,
                    controller: paidQtyController,
                    onIncrement: () {
                      setDialogState(() {
                        paidQty += 1;
                        syncController(paidQtyController, paidQty);
                      });
                    },
                    onDecrement: () {
                      setDialogState(() {
                        if (paidQty > 0) paidQty -= 1;
                        syncController(paidQtyController, paidQty);
                      });
                    },
                    onManualChanged: (value) {
                      setDialogState(() => paidQty = parseQty(value));
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: hasGift,
                      onChanged: (value) {
                        setDialogState(() {
                          hasGift = value ?? false;
                          if (!hasGift) {
                            giftQty = 0;
                            syncController(giftQtyController, giftQty);
                          } else if (giftQty == 0) {
                            giftQty = 1;
                            syncController(giftQtyController, giftQty);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'يوجد هدية',
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: const Text(
                        'الهدية لا تؤثر على إجمالي السعر',
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasGift)
                    _QuantityStepperField(
                      label: 'الهدية',
                      icon: Icons.card_giftcard,
                      controller: giftQtyController,
                      onIncrement: () {
                        setDialogState(() {
                          giftQty += 1;
                          syncController(giftQtyController, giftQty);
                        });
                      },
                      onDecrement: () {
                        setDialogState(() {
                          if (giftQty > 0) giftQty -= 1;
                          syncController(giftQtyController, giftQty);
                        });
                      },
                      onManualChanged: (value) {
                        setDialogState(() => giftQty = parseQty(value));
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('تحديث'),
                onPressed: () {
                  paidQty = parseQty(paidQtyController.text);
                  giftQty = hasGift ? parseQty(giftQtyController.text) : 0;

                  if (paidQty == 0 && giftQty == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'يرجى إدخال كمية أو تفعيل الهدية ثم تحديد كميتها',
                        ),
                      ),
                    );
                    return;
                  }

                  final isGiftOnly = paidQty == 0 && giftQty > 0;
                  setState(() {
                    _orderItems[index] = OrderItemData(
                      medicineId: item.medicineId,
                      medicineName: item.medicineName,
                      companyId: item.companyId,
                      companyName: item.companyName,
                      qty: paidQty,
                      price: item.price,
                      isGift: isGiftOnly,
                      giftQty: giftQty,
                    );
                  });

                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      paidQtyController.dispose();
      giftQtyController.dispose();
    }
  }

  Future<void> _saveOrder() async {
    final isEditMode = widget.editOrderId != null;

    // Only check offline limit when creating a new order
    if (!isEditMode) {
      final activationService = getIt<ActivationService>();
      final offlineLimitExceeded =
          await activationService.isOfflineLimitExceeded();
      if (offlineLimitExceeded) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/offline-limit');
        }
        return;
      }
    }

    // Validation: pharmacy
    if (_selectedPharmacyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصيدلية')),
      );
      return;
    }

    // Validation: at least one item (medicines or gifts)
    if (_orderItems.isEmpty && _giftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة عنصر واحد على الأقل للطلبية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (isEditMode) {
        // ── Edit mode: update order + replace all items atomically ──────
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          // Update the order's pharmacy (in case it was changed)
          await txn.update(
            'orders',
            {'pharmacy_id': _selectedPharmacyId},
            where: 'id = ?',
            whereArgs: [widget.editOrderId],
          );
          // Delete ALL existing items for this order
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [widget.editOrderId],
          );
          // Delete existing gift items
          await txn.delete(
            'order_gift_items',
            where: 'order_id = ?',
            whereArgs: [widget.editOrderId],
          );
          // Re-insert the current items
          for (final item in _orderItems) {
            await txn.insert('order_items', {
              'order_id':    widget.editOrderId,
              'medicine_id': item.medicineId,
              'qty':         item.qty,
              'price':       item.price,
              'is_gift':     item.isGift ? 1 : 0,
              'gift_qty':    item.giftQty,
            });
          }
          // Re-insert gift items
          for (final g in _giftItems) {
            await txn.insert('order_gift_items', {
              'order_id': widget.editOrderId,
              'gift_id':  g.giftId,
              'qty':      g.qty,
            });
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ التعديلات بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          // Pop back to OrderDetailsScreen; pass true so it refreshes
          Navigator.pop(context, true);
        }
      } else {
        // ── Create mode: original logic ─────────────────────────────────
        final now = DateTime.now().toIso8601String();

        // Generate unique invoice number using userId as prefix
        final activationService = getIt<ActivationService>();
        final userId = await activationService.getUserId();
        final invoiceService = await InvoiceNumberService.create();
        final invoiceNumber = await invoiceService.nextInvoiceNumber(userId);

        final orderId = await _dbHelper.insert('orders', {
          'pharmacy_id':    _selectedPharmacyId,
          'created_at':     now,
          'invoice_number': invoiceNumber,
        });

        for (final item in _orderItems) {
          await _dbHelper.insert('order_items', {
            'order_id':    orderId,
            'medicine_id': item.medicineId,
            'qty':         item.qty,
            'price':       item.price,
            'is_gift':     item.isGift ? 1 : 0,
            'gift_qty':    item.giftQty,
          });
        }

        for (final g in _giftItems) {
          await _dbHelper.insert('order_gift_items', {
            'order_id': orderId,
            'gift_id':  g.giftId,
            'qty':      g.qty,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الطلبية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            SlidePageRoute(
              page: OrderDetailsScreen(orderId: orderId),
              direction: SlideDirection.rightToLeft,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
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
      appBar: CustomAppBar(
          title: widget.editOrderId != null ? 'تعديل الطلبية' : 'إنشاء طلبية جديدة'),
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
                          FormSection(
                            title: 'اختيار الصيدلية',
                            icon: Icons.local_pharmacy_rounded,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _selectedPharmacyId,
                                      decoration: const InputDecoration(
                                        labelText: 'اختر الصيدلية *',
                                        hintText: 'اختر صيدلية من القائمة',
                                        prefixIcon: Icon(Icons.local_pharmacy_rounded),
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
                                  Tooltip(
                                    message: 'إضافة صيدلية جديدة',
                                    child: Material(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: _showAddPharmacyDialog,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Section 2: Medicine Search + Selection
                          FormSection(
                            title: 'بحث وإضافة الأدوية',
                            icon: Icons.medication_rounded,
                            children: [
                                  TextField(
                                    controller: _medicineSearchController,
                                    decoration: const InputDecoration(
                                      labelText: 'بحث عن دواء',
                                      hintText: 'أدخل اسم الدواء للبحث...',
                                      prefixIcon: Icon(Icons.search_rounded),
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  // Medicine search results
                                  if (_hasSearched &&
                                      _medicinesWithCompanies.isEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 24),
                                      decoration: BoxDecoration(
                                        color: theme.brightness ==
                                                Brightness.dark
                                            ? Colors.orange.shade900
                                                .withValues(alpha: 0.15)
                                            : Colors.orange.shade50,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.orange.shade800
                                              : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.search_off_rounded,
                                            size: 48,
                                            color: Colors.orange.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'لم يتم العثور على الدواء',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.orange.shade200
                                                  : Colors.orange.shade900,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'يمكنك إضافته من صفحة الأدوية',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.orange.shade300
                                                  : Colors.orange.shade700,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (_medicinesWithCompanies
                                      .isNotEmpty) ...[
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
                          const SizedBox(height: 8),

                          // Section 3: Gift Items
                          _buildSectionHeader('3', 'بحث وإضافة الهدايا', Icons.card_giftcard_rounded),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _giftSearchController,
                                    decoration: const InputDecoration(
                                      labelText: 'بحث عن هدية',
                                      hintText: 'أدخل اسم الهدية...',
                                      prefixIcon: Icon(Icons.search_rounded),
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  if (_hasGiftSearched && _giftsSearchResults.isEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'لم يتم العثور على الهدية. يمكنك إضافتها من صفحة الهدايا.',
                                      style: TextStyle(color: Colors.orange.shade700),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ] else if (_giftsSearchResults.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                      ),
                                      constraints: const BoxConstraints(maxHeight: 160),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: _giftsSearchResults.length,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                                          itemBuilder: (_, i) {
                                            final g = _giftsSearchResults[i];
                                            return ListTile(
                                              onTap: () => _onGiftSelected(g),
                                              leading: const Icon(Icons.card_giftcard_rounded),
                                              title: Text(g.name, textDirection: TextDirection.rtl),
                                              subtitle: (g.notes ?? '').isNotEmpty
                                                  ? Text(g.notes!, textDirection: TextDirection.rtl, style: Theme.of(context).textTheme.bodySmall)
                                                  : null,
                                              trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
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
                          const SizedBox(height: 8),
                          if (_giftItems.isNotEmpty)
                            Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_giftItems.length} هدية',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                        const Text('اسحب لحذف', style: TextStyle(fontSize: 12, color: Colors.grey), textDirection: TextDirection.rtl),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _giftItems.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final g = _giftItems[index];
                                      return Dismissible(
                                        key: Key('gift_item_$index'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          color: Colors.red,
                                          child: const Icon(Icons.delete, color: Colors.white, size: 28),
                                        ),
                                        onDismissed: (_) => _removeGiftItem(index),
                                        child: ListTile(
                                          onTap: () => _editGiftItemQty(index),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                g.qty.toString(),
                                                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          title: Text(g.giftName, style: const TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
                                          subtitle: (g.giftNotes ?? '').isNotEmpty
                                              ? Text(g.giftNotes!, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12))
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                                onPressed: () => _editGiftItemQty(index),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                onPressed: () => _removeGiftItem(index),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Section 4: Current Order Items
                          _buildSectionHeader('4', 'عناصر الطلبية', Icons.shopping_cart_rounded),
                          const SizedBox(height: 8),
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
                                          onTap: () =>
                                              _editItemQuantity(index),
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
                                                item.qty > 0
                                                    ? item.qty.toString()
                                                    : (item.giftQty > 0
                                                        ? '🎁'
                                                        : '0'),
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
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.blue,
                                                ),
                                                tooltip: 'تعديل الكمية',
                                                onPressed: () =>
                                                    _editItemQuantity(index),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                tooltip: 'حذف',
                                                onPressed: () =>
                                                    _removeItem(index),
                                              ),
                                            ],
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isSaving || (_orderItems.isEmpty && _giftItems.isEmpty)
                              ? null
                              : _saveOrder,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 22),
                          label: Text(
                            _isSaving
                                ? 'جارٍ الحفظ...'
                                : widget.editOrderId != null
                                    ? 'حفظ التعديلات (${_orderItems.length + _giftItems.length})'
                                    : 'حفظ الطلبية ${(_orderItems.isEmpty && _giftItems.isEmpty) ? '' : '(${_orderItems.length + _giftItems.length})'}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBackgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
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

class _QuantityStepperField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onManualChanged;

  const _QuantityStepperField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.onIncrement,
    required this.onDecrement,
    required this.onManualChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'تنقيص',
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: onManualChanged,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'زيادة',
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/pharmacy.dart';
import '../../core/services/activation_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state.dart';
import 'pharmacy_form.dart';

class PharmaciesScreen extends StatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ActivationService _activationService = ActivationService();
  List<Pharmacy> _pharmacies = [];
  List<Pharmacy> _filteredPharmacies = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    _searchController.addListener(_filterPharmacies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final maps = await _dbHelper.query('pharmacies', orderBy: 'name');
      setState(() {
        _pharmacies = maps.map((map) => Pharmacy.fromMap(map)).toList();
        _filteredPharmacies = _pharmacies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterPharmacies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPharmacies = _pharmacies;
      } else {
        _filteredPharmacies = _pharmacies
            .where((pharmacy) {
              final address = (pharmacy.address ?? '').toLowerCase();
              final phone = pharmacy.phone ?? '';
              return pharmacy.name.toLowerCase().contains(query) ||
                  address.contains(query) ||
                  phone.contains(query);
            })
            .toList();
      }
    });
  }

  Future<void> _deletePharmacy(Pharmacy pharmacy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${pharmacy.name}؟'),
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
          'pharmacies',
          where: 'id = ?',
          whereArgs: [pharmacy.id],
        );
        _loadPharmacies();
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

  Future<void> _navigateToForm(Pharmacy? pharmacy) async {
    // If adding new pharmacy, check trial limit first
    if (pharmacy == null) {
      try {
        await _activationService.checkTrialLimitPharmacies();
      } on TrialExpiredException {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('وصلت للحد المسموح'),
              content: const Text(
                  'وصلت للحد المسموح في النسخة التجريبية. يرجى التواصل مع المطور لتفعيل التطبيق.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/activation',
                      (route) => false,
                    );
                  },
                  child: const Text('تواصل مع المطور'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final result = await Navigator.push(
      context,
      SlidePageRoute(
        page: PharmacyForm(pharmacy: pharmacy),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      _loadPharmacies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'الصيدليات'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث عن صيدلية...',
                  prefixIcon: const Icon(Icons.search),
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPharmacies.isEmpty
                      ? EmptyState(
                          icon: _searchController.text.isEmpty
                              ? Icons.local_pharmacy
                              : Icons.search_off,
                          title: _searchController.text.isEmpty
                              ? 'لا توجد صيدليات'
                              : 'لا توجد نتائج',
                          message: _searchController.text.isEmpty
                              ? 'ابدأ بإضافة صيدلية جديدة'
                              : 'لم يتم العثور على صيدليات تطابق البحث',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPharmacies.length,
                          itemBuilder: (context, index) {
                            final pharmacy = _filteredPharmacies[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.local_pharmacy,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                title: Text(
                                  pharmacy.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((pharmacy.address ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                pharmacy.address!.trim(),
                                                style:
                                                    theme.textTheme.bodyMedium,
                                                textDirection:
                                                    TextDirection.rtl,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if ((pharmacy.phone ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        if ((pharmacy.address ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              pharmacy.phone!.trim(),
                                              style:
                                                  theme.textTheme.bodyMedium,
                                              textDirection:
                                                  TextDirection.rtl,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _navigateToForm(pharmacy),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.edit,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _deletePharmacy(pharmacy),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صيدلية'),
      ),
    );
  }
}

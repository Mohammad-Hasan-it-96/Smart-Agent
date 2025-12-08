import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/medicine.dart';
import '../../core/models/company.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/activation_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state.dart';
import 'medicine_form.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SettingsService _settingsService = SettingsService();
  final ActivationService _activationService = ActivationService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Data
  List<Company> _companies = [];
  Map<int, List<Map<String, dynamic>>> _medicinesByCompany = {};
  List<Map<String, dynamic>> _filteredMedicines = [];
  Set<int> _expandedCompanies = {};

  // Filtering
  int? _selectedCompanyId;
  String _searchQuery = '';

  // Pagination
  static const int _pageSize = 50;
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _isInitialLoading = true;
  Timer? _debounceTimer;

  // Pricing
  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  double _exchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
    _loadCompanies();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPricingSettings() async {
    final enabled = await _settingsService.isPricingEnabled();
    final mode = await _settingsService.getCurrencyMode();
    final rate = await _settingsService.getExchangeRate();
    setState(() {
      _pricingEnabled = enabled;
      _currencyMode = mode;
      _exchangeRate = rate;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final maps = await _dbHelper.query('companies', orderBy: 'name');
      setState(() {
        _companies = maps.map((map) => Company.fromMap(map)).toList();
      });
      await _loadMedicines();
    } catch (e) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMedicines({bool loadMore = false}) async {
    // Prevent multiple simultaneous loads
    if (_isLoading) return;

    // Prevent initial load if already loading initially
    if (!loadMore && _isInitialLoading && _isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _isInitialLoading = true;
        _currentPage = 0;
        _filteredMedicines.clear();
        _medicinesByCompany.clear();
      }
    });

    try {
      final db = await _dbHelper.database;
      final offset = loadMore ? _currentPage * _pageSize : 0;

      List<Map<String, dynamic>> maps;

      // Optimized query: Use simple SELECT with indexed columns
      if (_searchQuery.isNotEmpty) {
        // Search query with LIMIT - uses idx_medicine_name index
        maps = await db.rawQuery(
            '''
          SELECT 
            medicines.id,
            medicines.name,
            medicines.company_id,
            companies.name as company_name
          FROM medicines
          LEFT JOIN companies ON medicines.company_id = companies.id
          WHERE medicines.name LIKE ?
          ${_selectedCompanyId != null ? 'AND medicines.company_id = ?' : ''}
          ORDER BY medicines.name
          LIMIT ? OFFSET ?
        ''',
            _selectedCompanyId != null
                ? ['%$_searchQuery%', _selectedCompanyId, _pageSize, offset]
                : ['%$_searchQuery%', _pageSize, offset]);
      } else if (_selectedCompanyId != null) {
        // Filter by company - uses idx_medicine_company index
        maps = await db.rawQuery('''
          SELECT 
            medicines.id,
            medicines.name,
            medicines.company_id,
            medicines.price_usd,
            companies.name as company_name
          FROM medicines
          LEFT JOIN companies ON medicines.company_id = companies.id
          WHERE medicines.company_id = ?
          ORDER BY medicines.name
          LIMIT ? OFFSET ?
        ''', [_selectedCompanyId, _pageSize, offset]);
      } else {
        // Load all medicines with pagination
        maps = await db.rawQuery('''
          SELECT 
            medicines.id,
            medicines.name,
            medicines.company_id,
            medicines.price_usd,
            companies.name as company_name
          FROM medicines
          LEFT JOIN companies ON medicines.company_id = companies.id
          ORDER BY medicines.name
          LIMIT ? OFFSET ?
        ''', [_pageSize, offset]);
      }

      if (mounted) {
        // Convert read-only query results to mutable lists
        final mutableMaps = List<Map<String, dynamic>>.from(maps);

        if (loadMore) {
          setState(() {
            _filteredMedicines.addAll(mutableMaps);
            _currentPage++;
            _hasMoreData = mutableMaps.length == _pageSize;
            _isLoading = false;
          });
        } else {
          // Group medicines by company for non-search mode (only if not filtering by specific company)
          if (_selectedCompanyId == null && _searchQuery.isEmpty) {
            final Map<int, List<Map<String, dynamic>>> grouped = {};
            for (final medicine in mutableMaps) {
              final companyId = medicine['company_id'] as int?;
              if (companyId != null) {
                // Create a new map to ensure mutability
                final medicineMap = Map<String, dynamic>.from(medicine);
                grouped.putIfAbsent(companyId, () => []).add(medicineMap);
              }
            }
            _medicinesByCompany = grouped;
          } else {
            // When filtering by company or searching, just store in filtered list
            // Also update medicinesByCompany for the selected company
            if (_selectedCompanyId != null) {
              _medicinesByCompany = {
                _selectedCompanyId!:
                    List<Map<String, dynamic>>.from(mutableMaps)
              };
            }
          }

          setState(() {
            _filteredMedicines = mutableMaps;
            _currentPage = 1;
            _hasMoreData = mutableMaps.length == _pageSize;
            _isLoading = false;
            _isInitialLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _currentPage = 0;
          _hasMoreData = true;
          _filteredMedicines.clear();
          _medicinesByCompany.clear();
        });
        _loadMedicines();
      }
    });
  }

  void _onScroll() {
    // Load more when scrolled to 80% of the list
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMoreData) {
      _loadMedicines(loadMore: true);
    }
  }

  void _onCompanyFilterChanged(int? companyId) {
    setState(() {
      _selectedCompanyId = companyId;
      _searchQuery = ''; // Clear search when filtering by company
      _searchController.clear();
      _currentPage = 0;
      _hasMoreData = true;
      _filteredMedicines.clear();
      _medicinesByCompany.clear();
    });
    _loadMedicines();
  }

  void _toggleCompany(int companyId) {
    setState(() {
      if (_expandedCompanies.contains(companyId)) {
        _expandedCompanies.remove(companyId);
      } else {
        _expandedCompanies.add(companyId);
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
    // If adding new medicine, check trial limit first
    if (medicine == null) {
      try {
        await _activationService.checkTrialLimitMedicines();
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
      SlidePageRoute(
        page: MedicineForm(medicine: medicineModel),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      _loadMedicines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'الأدوية'),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث عن دواء...',
                  prefixIcon: const Icon(Icons.search),
                ),
                textDirection: TextDirection.rtl,
              ),
            ),

            // Company filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<int>(
                value: _selectedCompanyId,
                decoration: InputDecoration(
                  labelText: 'تصفية حسب الشركة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.filter_list),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('جميع الشركات'),
                  ),
                  ..._companies.map((company) {
                    return DropdownMenuItem<int>(
                      value: company.id,
                      child: Text(
                        company.name,
                        textDirection: TextDirection.rtl,
                      ),
                    );
                  }),
                ],
                onChanged: _onCompanyFilterChanged,
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة دواء'),
      ),
    );
  }

  Widget _buildContent() {
    // If searching, show flat list
    if (_searchQuery.isNotEmpty) {
      if (_filteredMedicines.isEmpty && !_isLoading) {
        return const EmptyState(
          icon: Icons.search_off,
          title: 'لا توجد نتائج',
          message: 'لم يتم العثور على أدوية تطابق البحث',
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount:
            _filteredMedicines.length + (_hasMoreData && _isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end when loading more
          if (index == _filteredMedicines.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final medicine = _filteredMedicines[index];
          return _buildMedicineCard(medicine, index: index);
        },
      );
    }

    // If filtering by company, show only that company's medicines
    if (_selectedCompanyId != null) {
      final companyMedicines = _medicinesByCompany[_selectedCompanyId] ?? [];
      if (companyMedicines.isEmpty && !_isLoading) {
        return const EmptyState(
          icon: Icons.medication_liquid,
          title: 'لا توجد أدوية',
          message: 'لا توجد أدوية مسجلة لهذه الشركة',
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount:
            companyMedicines.length + (_hasMoreData && _isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == companyMedicines.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final medicine = companyMedicines[index];
          return _buildMedicineCard(medicine, index: index);
        },
      );
    }

    // Default: show grouped by company with expandable tiles
    if (_medicinesByCompany.isEmpty && !_isLoading) {
      return const EmptyState(
        icon: Icons.medication_liquid,
        title: 'لا توجد أدوية',
        message: 'ابدأ بإضافة أدوية جديدة',
        action: SizedBox.shrink(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final company = _companies[index];
        final medicines = _medicinesByCompany[company.id] ?? [];

        if (medicines.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.business),
            title: Text(
              company.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(
              '${medicines.length} دواء',
              textDirection: TextDirection.rtl,
            ),
            initiallyExpanded: _expandedCompanies.contains(company.id),
            onExpansionChanged: (expanded) {
              _toggleCompany(company.id!);
            },
            children: medicines.asMap().entries.map((entry) {
              final index = entry.key;
              final medicine = entry.value;
              return TweenAnimationBuilder<double>(
                key: ValueKey('medicine_tile_${medicine['id']}_$index'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildMedicineTile(medicine),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine, {int? index}) {
    final cardWidget = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToForm(medicine),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          title: Text(
            medicine['name'] as String,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الشركة: ${medicine['company_name'] ?? 'غير محدد'}',
                style: const TextStyle(fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
              if (_pricingEnabled) ...[
                const SizedBox(height: 4),
                FutureBuilder<String>(
                  future: _getPriceDisplay(medicine),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        snapshot.data!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textDirection: TextDirection.rtl,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToForm(medicine),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.edit),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _deleteMedicine(medicine),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.delete, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Only animate if index is provided (for initial load)
    if (index != null) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('medicine_${medicine['id']}_$index'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index % 5) * 50),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  Widget _buildMedicineTile(Map<String, dynamic> medicine) {
    return InkWell(
      onTap: () => _navigateToForm(medicine),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                medicine['name'] as String,
                style: const TextStyle(fontSize: 16),
                textDirection: TextDirection.rtl,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToForm(medicine),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, size: 20),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _deleteMedicine(medicine),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.delete, color: Colors.red, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getPriceDisplay(Map<String, dynamic> medicine) async {
    final priceUsd = (medicine['price_usd'] as num?)?.toDouble() ?? 0.0;
    if (priceUsd <= 0) return '';

    double displayPrice = priceUsd;
    if (_currencyMode == 'syp') {
      displayPrice = priceUsd * _exchangeRate;
    }

    final symbol = _currencyMode == 'syp' ? 'ل.س' : '\$';
    return 'السعر: ${displayPrice.toStringAsFixed(2)} $symbol';
  }
}

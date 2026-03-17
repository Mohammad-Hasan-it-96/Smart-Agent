import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/models/company.dart';
import '../../core/models/medicine.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/index/index_design_system.dart';
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

  static const int _pageSize = 50;

  List<Company> _companies = [];
  List<Map<String, dynamic>> _medicines = [];
  List<String> _availableCategories = [];

  int _currentPage = 0;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasMoreData = true;

  int? _selectedCompanyId;
  String _searchQuery = '';
  String? _selectedCategory;
  bool? _availabilityFilter;
  RangeValues _activePriceRange = const RangeValues(0, 500);
  RangeValues _draftPriceRange = const RangeValues(0, 500);
  double _priceSliderMax = 500;

  Timer? _debounceTimer;

  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  double _exchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    await _loadPricingSettings();
    await _loadCompanies();
    await _refreshFiltersMetadata();
    await _loadMedicines();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingSettings() async {
    final enabled = await _settingsService.isPricingEnabled();
    final mode = await _settingsService.getCurrencyMode();
    final rate = await _settingsService.getExchangeRate();

    if (!mounted) return;
    setState(() {
      _pricingEnabled = enabled;
      _currencyMode = mode;
      _exchangeRate = rate;
    });
  }

  Future<void> _loadCompanies() async {
    try {
      final maps = await _dbHelper.query('companies', orderBy: 'name');
      if (!mounted) return;
      setState(() {
        _companies = maps.map((map) => Company.fromMap(map)).toList();
      });
    } catch (_) {
      // Keep UI responsive even if companies query fails.
    }
  }

  Future<void> _refreshFiltersMetadata() async {
    try {
      final db = await _dbHelper.database;
      final activePriceColumn =
          _currencyMode == 'syp' ? 'price_syp' : 'price_usd';
      final maxPriceResult = await db.rawQuery('''
        SELECT MAX(COALESCE($activePriceColumn, 0)) as max_price
        FROM medicines
      ''');
      final maxPrice =
          ((maxPriceResult.first['max_price'] as num?)?.toDouble() ?? 0).ceil();
      final normalizedMax = math.max(100, maxPrice + 50).toDouble();

      final categoriesResult = await db.rawQuery('''
        SELECT DISTINCT TRIM(form) AS category
        FROM medicines
        WHERE form IS NOT NULL AND TRIM(form) <> ''
        ORDER BY category ASC
      ''');

      final categories = categoriesResult
          .map((row) => (row['category'] as String?)?.trim())
          .whereType<String>()
          .toList();

      if (!mounted) return;
      setState(() {
        _priceSliderMax = normalizedMax;
        _activePriceRange = RangeValues(
          _activePriceRange.start.clamp(0, normalizedMax),
          _activePriceRange.end.clamp(0, normalizedMax),
        );
        _draftPriceRange = _activePriceRange;
        _availableCategories = categories;
        if (_selectedCategory != null &&
            !_availableCategories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _priceSliderMax = 500;
        _activePriceRange = const RangeValues(0, 500);
        _draftPriceRange = _activePriceRange;
      });
    }
  }

  Future<void> _loadMedicines({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _isInitialLoading = true;
        _currentPage = 0;
        _hasMoreData = true;
      }
    });

    try {
      final db = await _dbHelper.database;
      final offset = loadMore ? _currentPage * _pageSize : 0;

      final whereParts = <String>[];
      final args = <Object?>[];

      if (_searchQuery.isNotEmpty) {
        whereParts.add('medicines.name LIKE ?');
        args.add('%$_searchQuery%');
      }

      if (_selectedCompanyId != null) {
        whereParts.add('medicines.company_id = ?');
        args.add(_selectedCompanyId);
      }

      if (_selectedCategory != null) {
        whereParts.add('TRIM(COALESCE(medicines.form, \'\')) = ?');
        args.add(_selectedCategory);
      }

      if (_availabilityFilter != null) {
        final activePriceColumn =
            _currencyMode == 'syp' ? 'medicines.price_syp' : 'medicines.price_usd';
        if (_availabilityFilter == true) {
          whereParts.add('COALESCE($activePriceColumn, 0) > 0');
        } else {
          whereParts.add('COALESCE($activePriceColumn, 0) <= 0');
        }
      }

      final activePriceColumn =
          _currencyMode == 'syp' ? 'medicines.price_syp' : 'medicines.price_usd';
      whereParts.add('COALESCE($activePriceColumn, 0) >= ?');
      args.add(_activePriceRange.start);
      whereParts.add('COALESCE($activePriceColumn, 0) <= ?');
      args.add(_activePriceRange.end);

      final whereClause =
          whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

      final maps = await db.rawQuery(
        '''
        SELECT
          medicines.id,
          medicines.name,
          medicines.company_id,
          medicines.price_usd,
          medicines.price_syp,
          medicines.form,
          medicines.source,
          medicines.notes,
          companies.name AS company_name,
          COALESCE(medicines.form, '') AS category,
          CASE WHEN COALESCE($activePriceColumn, 0) > 0 THEN 1 ELSE 0 END AS is_available,
          NULL AS stock_qty
        FROM medicines
        LEFT JOIN companies ON companies.id = medicines.company_id
        $whereClause
        ORDER BY medicines.name ASC
        LIMIT ? OFFSET ?
        ''',
        [...args, _pageSize, offset],
      );

      final mutableMaps = List<Map<String, dynamic>>.from(maps);

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _medicines.addAll(mutableMaps);
        } else {
          _medicines = mutableMaps;
        }
        _currentPage = loadMore ? _currentPage + 1 : 1;
        _hasMoreData = mutableMaps.length == _pageSize;
        _isLoading = false;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query == _searchQuery) return;

      setState(() {
        _searchQuery = query;
      });
      _loadMedicines();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMoreData) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      _loadMedicines(loadMore: true);
    }
  }

  Future<void> _openAdvancedFilters() async {
    _draftPriceRange = _activePriceRange;

    final selected = await showModalBottomSheet<_FiltersResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? draftCategory = _selectedCategory;
        bool? draftAvailability = _availabilityFilter;
        int? draftCompanyId = _selectedCompanyId;
        RangeValues draftRange = _draftPriceRange;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  right: 16,
                  left: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'فلاتر متقدمة',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int?>(
                        initialValue: draftCompanyId,
                        decoration: const InputDecoration(
                          labelText: 'الشركة',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('جميع الشركات'),
                          ),
                          ..._companies.map((company) => DropdownMenuItem<int?>(
                                value: company.id,
                                child: Text(company.name),
                              )),
                        ],
                        onChanged: (value) {
                          setSheetState(() => draftCompanyId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: draftCategory,
                        decoration: const InputDecoration(
                          labelText: 'الفئة (الشكل الدوائي)',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('كل الفئات'),
                          ),
                          ..._availableCategories.map(
                            (category) => DropdownMenuItem<String?>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => draftCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<bool?>(
                        initialValue: draftAvailability,
                        decoration: const InputDecoration(
                          labelText: 'التوفر',
                          prefixIcon: Icon(Icons.inventory_2_rounded),
                        ),
                        items: const [
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text('الكل'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Text('متوفر'),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Text('غير متوفر'),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => draftAvailability = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'نطاق السعر (${_currencyMode == 'syp' ? 'ل.س' : 'USD'})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: draftRange,
                        min: 0,
                        max: _priceSliderMax,
                        divisions: 20,
                        labels: RangeLabels(
                          draftRange.start.toStringAsFixed(0),
                          draftRange.end.toStringAsFixed(0),
                        ),
                        onChanged: (values) {
                          setSheetState(() => draftRange = values);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(draftRange.start.toStringAsFixed(0)),
                          Text(draftRange.end.toStringAsFixed(0)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  const _FiltersResult.reset(),
                                );
                              },
                              child: const Text('إعادة تعيين'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  _FiltersResult(
                                    companyId: draftCompanyId,
                                    category: draftCategory,
                                    availability: draftAvailability,
                                    priceRange: draftRange,
                                    reset: false,
                                  ),
                                );
                              },
                              child: const Text('تطبيق'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (selected.reset) {
        _selectedCompanyId = null;
        _selectedCategory = null;
        _availabilityFilter = null;
        _activePriceRange = RangeValues(0, _priceSliderMax);
      } else {
        _selectedCompanyId = selected.companyId;
        _selectedCategory = selected.category;
        _availabilityFilter = selected.availability;
        _activePriceRange = selected.priceRange;
      }
    });

    _loadMedicines();
  }

  Future<void> _deleteMedicine(Map<String, dynamic> medicine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text(
          'هل تريد حذف ${medicine['name']}؟',
          textDirection: TextDirection.rtl,
        ),
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

    if (confirm != true) return;

    try {
      await _dbHelper.delete(
        'medicines',
        where: 'id = ?',
        whereArgs: [medicine['id']],
      );
      await _refreshFiltersMetadata();
      await _loadMedicines();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الدواء بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الدواء')),
      );
    }
  }

  Future<void> _navigateToForm(Map<String, dynamic>? medicine) async {
    if (medicine == null) {
      try {
        await _activationService.checkTrialLimitMedicines();
      } on TrialExpiredException {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('وصلت للحد المسموح'),
            content: const Text(
              'وصلت للحد المسموح في النسخة التجريبية. يرجى التواصل مع المطور لتفعيل التطبيق.',
              textDirection: TextDirection.rtl,
            ),
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
        return;
      }
    }

    Medicine? medicineModel;
    if (medicine != null) {
      try {
        final maps = await _dbHelper.query(
          'medicines',
          where: 'id = ?',
          whereArgs: [medicine['id']],
          limit: 1,
        );

        if (maps.isNotEmpty) {
          medicineModel = Medicine.fromMap(maps.first);
        }
      } catch (_) {
        medicineModel = Medicine(
          id: medicine['id'] as int,
          name: medicine['name'] as String,
          companyId: medicine['company_id'] as int,
        );
      }
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      SlidePageRoute(
        page: MedicineForm(medicine: medicineModel),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      await _refreshFiltersMetadata();
      await _loadMedicines();
    }
    }

  Future<void> _showDetails(Map<String, dynamic> medicine) async {
    final priceText = await _getPriceDisplay(medicine);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine['name'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _DetailsLine(
                  icon: Icons.business_rounded,
                  label: 'الشركة',
                  value: medicine['company_name']?.toString() ?? 'غير محدد',
                ),
                _DetailsLine(
                  icon: Icons.category_rounded,
                  label: 'الفئة',
                  value: (medicine['category'] as String?)?.isNotEmpty == true
                      ? medicine['category'].toString()
                      : 'غير محدد',
                ),
                _DetailsLine(
                  icon: Icons.inventory_2_rounded,
                  label: 'المخزون',
                  value: _stockText(medicine),
                ),
                if (_pricingEnabled && priceText.isNotEmpty)
                  _DetailsLine(
                    icon: Icons.attach_money_rounded,
                    label: 'السعر',
                    value: priceText.replaceFirst('السعر: ', ''),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _stockText(Map<String, dynamic> medicine) {
    final stock = (medicine['stock_qty'] as num?)?.toInt();
    if (stock == null) return 'غير متوفر';
    return stock.toString();
  }

  String _availabilityText(bool? availability) {
    if (availability == null) return 'الكل';
    return availability ? 'متوفر' : 'غير متوفر';
  }

  bool get _hasActiveFilters {
    return _selectedCompanyId != null ||
        _selectedCategory != null ||
        _availabilityFilter != null ||
        _activePriceRange.start > 0 ||
        _activePriceRange.end < _priceSliderMax;
  }

    Widget _buildHeader() {
    return IndexHeaderSection(
      searchController: _searchController,
      searchQuery: _searchQuery,
      hintText: 'ابحث باسم الدواء...',
      controls: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openAdvancedFilters,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('فلاتر متقدمة'),
            ),
          ),
          const SizedBox(width: 10),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCompanyId = null;
                  _selectedCategory = null;
                  _availabilityFilter = null;
                  _activePriceRange = RangeValues(0, _priceSliderMax);
                });
                _loadMedicines();
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('مسح'),
            ),
        ],
      ),
      filterChips: [
        if (_selectedCompanyId != null)
          IndexFilterChip(
            text:
                'الشركة: ${_companies.firstWhere((c) => c.id == _selectedCompanyId).name}',
          ),
        if (_selectedCategory != null)
          IndexFilterChip(text: 'الفئة: $_selectedCategory'),
        if (_availabilityFilter != null)
          IndexFilterChip(text: 'التوفر: ${_availabilityText(_availabilityFilter)}'),
        if (_hasActiveFilters)
          IndexFilterChip(
            text:
                'السعر: ${_activePriceRange.start.toStringAsFixed(0)} - ${_activePriceRange.end.toStringAsFixed(0)}',
          ),
      ],
    );
    }

    Widget _buildEmptyState() {
    final isSearch = _searchQuery.isNotEmpty || _hasActiveFilters;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: IndexEmptySection(
        icon: isSearch ? Icons.search_off_rounded : Icons.medication_outlined,
        title: isSearch ? 'لا توجد نتائج' : 'لا توجد أدوية بعد',
        message: isSearch
            ? 'جرّب تغيير البحث أو الفلاتر للوصول إلى نتائج.'
            : 'ابدأ بإضافة أول دواء ليظهر هنا.',
        onAdd: () => _navigateToForm(null),
        addLabel: 'إضافة دواء',
      ),
    );
    }

    Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final theme = Theme.of(context);

    return Card(
      margin: IndexUiTokens.cardMargin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius),
      ),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius),
        onTap: () => _showDetails(medicine),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        medicine['name'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'details') {
                          await _showDetails(medicine);
                        } else if (value == 'edit') {
                          await _navigateToForm(medicine);
                        } else if (value == 'delete') {
                          await _deleteMedicine(medicine);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'details', child: Text('التفاصيل')),
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IndexInfoChip(
                      icon: Icons.business_rounded,
                      text: medicine['company_name']?.toString() ?? 'غير محدد',
                    ),
                    IndexInfoChip(
                      icon: Icons.attach_money_rounded,
                      text: _pricingEnabled
                          ? _syncPriceText(medicine)
                          : 'السعر مخفي',
                    ),
                    IndexInfoChip(
                      icon: Icons.inventory_2_rounded,
                      text: 'المخزون: ${_stockText(medicine)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    }

  String _syncPriceText(Map<String, dynamic> medicine) {
    final usd = (medicine['price_usd'] as num?)?.toDouble();
    final syp = (medicine['price_syp'] as num?)?.toDouble();
    final isSypMode = _currencyMode == 'syp';
    final selected = isSypMode ? syp : usd;

    if (selected != null && selected > 0) {
      final symbol = isSypMode ? 'ل.س' : '\$';
      return '${selected.toStringAsFixed(2)} $symbol';
    }

    final fallback = isSypMode ? usd : syp;
    if (fallback != null && fallback > 0) {
      final fallbackSymbol = isSypMode ? '\$' : 'ل.س';
      return '${fallback.toStringAsFixed(2)} $fallbackSymbol (بديل)';
    }

    return 'السعر غير محدد';
  }

  Future<String> _getPriceDisplay(Map<String, dynamic> medicine) async {
    return 'السعر: ${_syncPriceText(medicine)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'الأدوية',
        showNotifications: true,
        showSettings: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة دواء'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshFiltersMetadata();
          await _loadMedicines();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                minHeight: _hasActiveFilters ? 190 : 138,
                maxHeight: _hasActiveFilters ? 190 : 138,
                child: _buildHeader(),
              ),
            ),
            if (_isInitialLoading)
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: SliverList.builder(
                  itemCount: 8,
                  itemBuilder: (context, index) => const IndexSkeletonCard(),
                ),
              )
            else if (_medicines.isEmpty)
              _buildEmptyState()
            else
              SliverList.builder(
                itemCount: _medicines.length + (_isLoading && _hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _medicines.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildMedicineCard(_medicines[index]);
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
    }
}

class _FiltersResult {
  final int? companyId;
  final String? category;
  final bool? availability;
  final RangeValues priceRange;
  final bool reset;

  const _FiltersResult({
    required this.companyId,
    required this.category,
    required this.availability,
    required this.priceRange,
    required this.reset,
  });

  const _FiltersResult.reset()
      : companyId = null,
        category = null,
        availability = null,
        priceRange = const RangeValues(0, 500),
        reset = true;
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 1 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.child != child;
  }
}

class _DetailsLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailsLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}


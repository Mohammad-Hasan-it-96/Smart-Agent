import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/models/pharmacy.dart';
import '../../core/services/activation_service.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/index/index_design_system.dart';
import 'pharmacy_form.dart';

enum _ActivityFilter { all, active, inactive }
enum _OrderVolumeFilter { all, low, medium, high }
enum _PharmacySort { name, newest, mostOrders }

class PharmaciesScreen extends StatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ActivationService _activationService = ActivationService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 40;

  List<_PharmacyListItem> _items = [];
  List<String> _cityOptions = [];

  int _currentPage = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  String _searchQuery = '';
  String? _selectedCity;
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  _OrderVolumeFilter _orderVolumeFilter = _OrderVolumeFilter.all;
  _PharmacySort _sort = _PharmacySort.name;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCityOptions();
    await _loadPharmacies(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCityOptions() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT DISTINCT address
        FROM pharmacies
        WHERE address IS NOT NULL AND TRIM(address) <> ''
      ''');

      final cities = <String>{};
      for (final row in rows) {
        final address = (row['address'] as String?)?.trim() ?? '';
        if (address.isEmpty) continue;
        cities.add(_extractCity(address));
      }

      if (!mounted) return;
      setState(() {
        _cityOptions = cities.toList()..sort((a, b) => a.compareTo(b));
        if (_selectedCity != null && !_cityOptions.contains(_selectedCity)) {
          _selectedCity = null;
        }
      });
    } catch (_) {
      // Ignore city list failures to keep page usable.
    }
  }

  String _extractCity(String address) {
    final cleaned = address.trim();
    if (cleaned.isEmpty) return cleaned;

    final separators = [',', '-', '،', '/'];
    for (final sep in separators) {
      if (cleaned.contains(sep)) {
        return cleaned.split(sep).first.trim();
      }
    }
    return cleaned;
  }

  Future<void> _loadPharmacies({required bool reset}) async {
    if (reset) {
      setState(() {
        _isInitialLoading = true;
        _isLoadingMore = false;
        _currentPage = 0;
        _hasMoreData = true;
      });
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final db = await _dbHelper.database;
      final offset = reset ? 0 : _currentPage * _pageSize;

      final whereParts = <String>[];
      final args = <Object?>[];

      if (_searchQuery.isNotEmpty) {
        whereParts.add('('
            'pharmacies.name LIKE ? OR '
            "COALESCE(pharmacies.phone, '') LIKE ? OR "
            "COALESCE(pharmacies.address, '') LIKE ?"
            ')');
        final q = '%$_searchQuery%';
        args.addAll([q, q, q]);
      }

      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        whereParts.add("COALESCE(pharmacies.address, '') LIKE ?");
        args.add('%$_selectedCity%');
      }

      final whereClause = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

      String havingClause = '';
      if (_activityFilter == _ActivityFilter.active) {
        havingClause = 'HAVING COUNT(DISTINCT orders.id) > 0';
      } else if (_activityFilter == _ActivityFilter.inactive) {
        havingClause = 'HAVING COUNT(DISTINCT orders.id) = 0';
      }

      if (_orderVolumeFilter != _OrderVolumeFilter.all) {
        final rangeClause = switch (_orderVolumeFilter) {
          _OrderVolumeFilter.low =>
            'COUNT(DISTINCT orders.id) BETWEEN 1 AND 10',
          _OrderVolumeFilter.medium =>
            'COUNT(DISTINCT orders.id) BETWEEN 11 AND 40',
          _OrderVolumeFilter.high =>
            'COUNT(DISTINCT orders.id) > 40',
          _OrderVolumeFilter.all => '1 = 1',
        };

        if (havingClause.isEmpty) {
          havingClause = 'HAVING $rangeClause';
        } else {
          havingClause = '$havingClause AND $rangeClause';
        }
      }

      final orderBy = switch (_sort) {
        _PharmacySort.name => 'pharmacies.name COLLATE NOCASE ASC',
        _PharmacySort.newest => 'pharmacies.id DESC',
        _PharmacySort.mostOrders => 'total_orders DESC, pharmacies.name COLLATE NOCASE ASC',
      };

      final rows = await db.rawQuery(
        '''
        SELECT
          pharmacies.id,
          pharmacies.name,
          pharmacies.phone,
          pharmacies.address,
          COUNT(DISTINCT orders.id) AS total_orders,
          COALESCE(
            SUM(
              CASE
                WHEN COALESCE(order_items.is_gift, 0) = 1 THEN 0
                ELSE COALESCE(order_items.qty, 0) * COALESCE(order_items.price, 0)
              END
            ),
            0
          ) AS balance
        FROM pharmacies
        LEFT JOIN orders ON orders.pharmacy_id = pharmacies.id
        LEFT JOIN order_items ON order_items.order_id = orders.id
        $whereClause
        GROUP BY pharmacies.id, pharmacies.name, pharmacies.phone, pharmacies.address
        $havingClause
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
        ''',
        [...args, _pageSize, offset],
      );

      final result = rows.map(_PharmacyListItem.fromMap).toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = result;
        } else {
          _items.addAll(result);
        }
        _currentPage = reset ? 1 : _currentPage + 1;
        _hasMoreData = result.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final q = _searchController.text.trim();
      if (q == _searchQuery) return;
      setState(() {
        _searchQuery = q;
      });
      _loadPharmacies(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreData) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.82) {
      _loadPharmacies(reset: false);
    }
  }

  Future<void> _deletePharmacy(_PharmacyListItem pharmacy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text(
          'هل تريد حذف ${pharmacy.name}؟',
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
        'pharmacies',
        where: 'id = ?',
        whereArgs: [pharmacy.id],
      );
      await _loadCityOptions();
      await _loadPharmacies(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الصيدلية بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الصيدلية')),
      );
    }
  }

  Future<void> _navigateToForm(Pharmacy? pharmacy) async {
    if (pharmacy == null) {
      try {
        await _activationService.checkTrialLimitPharmacies();
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

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      SlidePageRoute(
        page: PharmacyForm(pharmacy: pharmacy),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      await _loadCityOptions();
      await _loadPharmacies(reset: true);
    }
  }

  String _orderVolumeLabel(int totalOrders) {
    if (totalOrders > 40) return 'مرتفع';
    if (totalOrders >= 11) return 'متوسط';
    if (totalOrders >= 1) return 'منخفض';
    return 'بدون طلبات';
  }

  Color _orderVolumeColor(BuildContext context, int totalOrders) {
    if (totalOrders > 40) return Colors.green;
    if (totalOrders >= 11) return Colors.blue;
    if (totalOrders >= 1) return Colors.orange;
    return Theme.of(context).colorScheme.outline;
  }

  String _sortLabel(_PharmacySort sort) {
    return switch (sort) {
      _PharmacySort.name => 'الاسم',
      _PharmacySort.newest => 'الأحدث',
      _PharmacySort.mostOrders => 'الأكثر طلباً',
    };
  }

  Widget _buildHeader() {
    final sortField = DropdownButtonFormField<_PharmacySort>(
      initialValue: _sort,
      decoration: const InputDecoration(
        labelText: 'الترتيب',
        prefixIcon: Icon(Icons.sort_rounded),
      ),
      items: _PharmacySort.values
          .map(
            (sort) => DropdownMenuItem<_PharmacySort>(
              value: sort,
              child: Text(_sortLabel(sort)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == _sort) return;
        setState(() => _sort = value);
        _loadPharmacies(reset: true);
      },
    );

    final cityField = DropdownButtonFormField<String?>(
      initialValue: _selectedCity,
      decoration: const InputDecoration(
        labelText: 'المدينة',
        prefixIcon: Icon(Icons.location_city_rounded),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('كل المدن'),
        ),
        ..._cityOptions.map(
          (city) => DropdownMenuItem<String?>(
            value: city,
            child: Text(city),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == _selectedCity) return;
        setState(() => _selectedCity = value);
        _loadPharmacies(reset: true);
      },
    );

    final activityFilter = SegmentedButton<_ActivityFilter>(
      selected: {_activityFilter},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment<_ActivityFilter>(
          value: _ActivityFilter.all,
          label: Text('الكل'),
        ),
        ButtonSegment<_ActivityFilter>(
          value: _ActivityFilter.active,
          label: Text('نشطة'),
        ),
        ButtonSegment<_ActivityFilter>(
          value: _ActivityFilter.inactive,
          label: Text('غير نشطة'),
        ),
      ],
      onSelectionChanged: (selection) {
        final value = selection.first;
        if (value == _activityFilter) return;
        setState(() => _activityFilter = value);
        _loadPharmacies(reset: true);
      },
    );

    final volumeFilter = SegmentedButton<_OrderVolumeFilter>(
      selected: {_orderVolumeFilter},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment<_OrderVolumeFilter>(
          value: _OrderVolumeFilter.all,
          label: Text('الحجم: الكل'),
        ),
        ButtonSegment<_OrderVolumeFilter>(
          value: _OrderVolumeFilter.low,
          label: Text('منخفض'),
        ),
        ButtonSegment<_OrderVolumeFilter>(
          value: _OrderVolumeFilter.medium,
          label: Text('متوسط'),
        ),
        ButtonSegment<_OrderVolumeFilter>(
          value: _OrderVolumeFilter.high,
          label: Text('مرتفع'),
        ),
      ],
      onSelectionChanged: (selection) {
        final value = selection.first;
        if (value == _orderVolumeFilter) return;
        setState(() => _orderVolumeFilter = value);
        _loadPharmacies(reset: true);
      },
    );

    return IndexHeaderSection(
      searchController: _searchController,
      searchQuery: _searchQuery,
      hintText: 'بحث بالاسم، الرقم، أو الموقع...',
      controls: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 460;
          if (isSmall) {
            return Column(
              children: [
                sortField,
                const SizedBox(height: 10),
                cityField,
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: activityFilter,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: volumeFilter,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: sortField),
                  const SizedBox(width: 10),
                  Expanded(child: cityField),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: activityFilter,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: volumeFilter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPharmacyCard(_PharmacyListItem item) {
    final theme = Theme.of(context);
    final isActive = item.totalOrders > 0;
    final volumeColor = _orderVolumeColor(context, item.totalOrders);

    return Card(
      margin: IndexUiTokens.cardMargin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius),
      ),
      child: Padding(
        padding: IndexUiTokens.cardPadding,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      item.initial,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.address.trim().isNotEmpty)
                          Text(
                            item.address,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToForm(item.toPharmacy());
                      } else if (value == 'delete') {
                        _deletePharmacy(item);
                      } else if (value == 'add') {
                        _navigateToForm(null);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'add',
                        child: Text('إضافة صيدلية'),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('تعديل'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.phone.trim().isNotEmpty)
                    IndexInfoChip(
                      icon: Icons.phone_rounded,
                      text: item.phone,
                    ),
                  IndexInfoChip(
                    icon: Icons.shopping_bag_rounded,
                    text: '${item.totalOrders} طلبية',
                    color: theme.colorScheme.primary,
                  ),
                  IndexInfoChip(
                    icon: Icons.account_balance_wallet_rounded,
                    text: '${item.balance.toStringAsFixed(0)} \$',
                    color: theme.colorScheme.tertiary,
                  ),
                  IndexInfoChip(
                    icon: isActive
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_outline_rounded,
                    text: isActive ? 'نشطة' : 'غير نشطة',
                    color: isActive ? Colors.green : Colors.orange,
                  ),
                  IndexInfoChip(
                    icon: Icons.stacked_bar_chart_rounded,
                    text: _orderVolumeLabel(item.totalOrders),
                    color: volumeColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isInitialLoading) {
      return ListView.builder(
        padding: IndexUiTokens.listBottomPadding,
        itemCount: 8,
        itemBuilder: (_, __) => const IndexSkeletonCard(),
      );
    }

    if (_items.isEmpty) {
      final hasFilters = _searchQuery.isNotEmpty ||
          _selectedCity != null ||
          _activityFilter != _ActivityFilter.all ||
          _orderVolumeFilter != _OrderVolumeFilter.all;

      return IndexEmptySection(
        icon: hasFilters ? Icons.search_off_rounded : Icons.local_pharmacy_rounded,
        title: hasFilters ? 'لا توجد نتائج' : 'لا توجد صيدليات بعد',
        message: hasFilters
            ? 'غيّر البحث أو الفلاتر للوصول إلى نتائج.'
            : 'ابدأ بإضافة صيدلية جديدة لإدارة الطلبات بسرعة.',
        onAdd: () => _navigateToForm(null),
        addLabel: 'إضافة صيدلية',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: IndexUiTokens.listBottomPadding,
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildPharmacyCard(_items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'الصيدليات',
        showNotifications: true,
        showSettings: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadCityOptions();
                  await _loadPharmacies(reset: true);
                },
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة صيدلية'),
      ),
    );
  }
}

class _PharmacyListItem {
  final int id;
  final String name;
  final String phone;
  final String address;
  final int totalOrders;
  final double balance;

  const _PharmacyListItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.totalOrders,
    required this.balance,
  });

  factory _PharmacyListItem.fromMap(Map<String, dynamic> map) {
    return _PharmacyListItem(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ص';
    return trimmed.characters.first.toUpperCase();
  }

  Pharmacy toPharmacy() {
    return Pharmacy(
      id: id,
      name: name,
      phone: phone.isEmpty ? null : phone,
      address: address.isEmpty ? null : address,
    );
  }
}



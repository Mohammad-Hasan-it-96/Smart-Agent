import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/models/company.dart';
import '../../core/services/activation_service.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/index/index_design_system.dart';
import 'company_form.dart';

enum _CompanySort { aToZ, newest, mostUsed }
enum _CompanyActivityFilter { all, active, inactive }

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ActivationService _activationService = ActivationService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 30;

  List<_CompanyListItem> _companies = [];

  int _currentPage = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  String _searchQuery = '';
  _CompanySort _selectedSort = _CompanySort.aToZ;
  _CompanyActivityFilter _activityFilter = _CompanyActivityFilter.all;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadCompanies(reset: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies({required bool reset}) async {
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
        whereParts.add('companies.name LIKE ?');
        args.add('%$_searchQuery%');
      }

      final whereClause = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

      String havingClause = '';
      if (_activityFilter == _CompanyActivityFilter.active) {
        havingClause = 'HAVING COUNT(medicines.id) > 0';
      } else if (_activityFilter == _CompanyActivityFilter.inactive) {
        havingClause = 'HAVING COUNT(medicines.id) = 0';
      }

      final orderBy = switch (_selectedSort) {
        _CompanySort.aToZ => 'companies.name COLLATE NOCASE ASC',
        _CompanySort.newest => 'companies.id DESC',
        _CompanySort.mostUsed => 'medicines_count DESC, companies.name COLLATE NOCASE ASC',
      };

      final rows = await db.rawQuery(
        '''
        SELECT
          companies.id,
          companies.name,
          COUNT(medicines.id) AS medicines_count
        FROM companies
        LEFT JOIN medicines ON medicines.company_id = companies.id
        $whereClause
        GROUP BY companies.id, companies.name
        $havingClause
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
        ''',
        [...args, _pageSize, offset],
      );

      final items = rows.map(_CompanyListItem.fromMap).toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _companies = items;
        } else {
          _companies.addAll(items);
        }

        _currentPage = reset ? 1 : _currentPage + 1;
        _hasMoreData = items.length == _pageSize;
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query == _searchQuery) return;

      setState(() {
        _searchQuery = query;
      });
      _loadCompanies(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreData) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      _loadCompanies(reset: false);
    }
  }

  Future<void> _deleteCompany(_CompanyListItem company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text(
          'هل تريد حذف ${company.name}؟',
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
        'companies',
        where: 'id = ?',
        whereArgs: [company.id],
      );
      await _loadCompanies(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الشركة بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الحذف')),
      );
    }
  }

  Future<void> _navigateToForm(Company? company) async {
    if (company == null) {
      try {
        await _activationService.checkTrialLimitCompanies();
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
        page: CompanyForm(company: company),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      await _loadCompanies(reset: true);
    }
  }

  String _sortLabel(_CompanySort sort) {
    return switch (sort) {
      _CompanySort.aToZ => 'أ-ي',
      _CompanySort.newest => 'الأحدث',
      _CompanySort.mostUsed => 'الأكثر استخداماً',
    };
  }

    Widget _buildHeader(BuildContext context) {
    final sortField = DropdownButtonFormField<_CompanySort>(
      initialValue: _selectedSort,
      decoration: const InputDecoration(
        labelText: 'الترتيب',
        prefixIcon: Icon(Icons.sort_rounded),
      ),
      items: _CompanySort.values
          .map(
            (sort) => DropdownMenuItem<_CompanySort>(
              value: sort,
              child: Text(_sortLabel(sort)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == _selectedSort) return;
        setState(() => _selectedSort = value);
        _loadCompanies(reset: true);
      },
    );

    final activityField = SegmentedButton<_CompanyActivityFilter>(
      selected: {_activityFilter},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment<_CompanyActivityFilter>(
          value: _CompanyActivityFilter.all,
          label: Text('الكل'),
        ),
        ButtonSegment<_CompanyActivityFilter>(
          value: _CompanyActivityFilter.active,
          label: Text('نشطة'),
        ),
        ButtonSegment<_CompanyActivityFilter>(
          value: _CompanyActivityFilter.inactive,
          label: Text('غير نشطة'),
        ),
      ],
      onSelectionChanged: (selection) {
        final value = selection.first;
        if (value == _activityFilter) return;
        setState(() => _activityFilter = value);
        _loadCompanies(reset: true);
      },
    );

    return IndexHeaderSection(
      searchController: _searchController,
      searchQuery: _searchQuery,
      hintText: 'ابحث عن شركة...',
      controls: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 430;
          if (isNarrow) {
            return Column(
              children: [
                sortField,
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: activityField,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: sortField),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: activityField,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    }

    Widget _buildCompanyCard(BuildContext context, _CompanyListItem company) {
    final theme = Theme.of(context);
    final isActive = company.medicinesCount > 0;

    return Card(
      margin: IndexUiTokens.cardMargin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius),
      ),
      elevation: 1.5,
      child: Padding(
        padding: IndexUiTokens.cardPadding,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  company.initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IndexInfoChip(
                          icon: Icons.medication_rounded,
                          text: '${company.medicinesCount} دواء',
                        ),
                        IndexInfoChip(
                          icon: isActive
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_outline_rounded,
                          text: isActive ? 'نشطة' : 'غير نشطة',
                          color: isActive ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _navigateToForm(company.toCompany());
                  } else if (value == 'delete') {
                    _deleteCompany(company);
                  } else if (value == 'add') {
                    _navigateToForm(null);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'add',
                    child: Text('إضافة شركة'),
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
        ),
      ),
    );
    }

    Widget _buildBody(BuildContext context) {
    if (_isInitialLoading) {
      return ListView.builder(
        padding: IndexUiTokens.listBottomPadding,
        itemCount: 8,
        itemBuilder: (_, __) => const IndexSkeletonCard(),
      );
    }

    if (_companies.isEmpty) {
      final hasSearchOrFilters = _searchQuery.isNotEmpty ||
          _selectedSort != _CompanySort.aToZ ||
          _activityFilter != _CompanyActivityFilter.all;

      return IndexEmptySection(
        icon: hasSearchOrFilters ? Icons.search_off_rounded : Icons.business_rounded,
        title: hasSearchOrFilters ? 'لا توجد نتائج' : 'لا توجد شركات بعد',
        message: hasSearchOrFilters
            ? 'جرّب تغيير البحث أو خيارات التصفية.'
            : 'ابدأ بإضافة شركة جديدة لتنظيم بيانات الأدوية بسهولة.',
        onAdd: () => _navigateToForm(null),
        addLabel: 'إضافة شركة',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: IndexUiTokens.listBottomPadding,
      itemCount: _companies.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _companies.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildCompanyCard(context, _companies[index]);
      },
    );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'الشركات',
        showNotifications: true,
        showSettings: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadCompanies(reset: true),
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة شركة'),
      ),
    );
  }
}

class _CompanyListItem {
  final int id;
  final String name;
  final int medicinesCount;

  const _CompanyListItem({
    required this.id,
    required this.name,
    required this.medicinesCount,
  });

  factory _CompanyListItem.fromMap(Map<String, dynamic> map) {
    return _CompanyListItem(
      id: map['id'] as int,
      name: map['name'] as String,
      medicinesCount: (map['medicines_count'] as num?)?.toInt() ?? 0,
    );
  }

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ش';
    return trimmed.characters.first.toUpperCase();
  }

  Company toCompany() => Company(id: id, name: name);
}



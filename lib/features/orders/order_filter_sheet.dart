import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/theme/app_theme.dart';
import 'order_filter.dart';

/// A draggable bottom sheet for configuring [OrderFilter].
/// Call via [showModalBottomSheet]; it pops with the new [OrderFilter] on apply.
class OrderFilterSheet extends StatefulWidget {
  final OrderFilter currentFilter;
  final DatabaseHelper dbHelper;

  const OrderFilterSheet({
    super.key,
    required this.currentFilter,
    required this.dbHelper,
  });

  @override
  State<OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<OrderFilterSheet> {
  late OrderFilter _local;

  // Data loaded from DB
  List<String> _months = [];
  List<FilterItem> _allPharmacies = [];
  List<FilterItem> _allCompanies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _local = widget.currentFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await widget.dbHelper.database;

      final monthRows = await db.rawQuery(
        "SELECT DISTINCT SUBSTR(created_at, 1, 7) AS m "
        "FROM orders ORDER BY m DESC LIMIT 36",
      );

      final pharmacyRows = await db.rawQuery('''
        SELECT DISTINCT p.id, p.name
        FROM pharmacies p
        JOIN orders o ON o.pharmacy_id = p.id
        ORDER BY p.name ASC
      ''');

      final companyRows = await db.rawQuery('''
        SELECT DISTINCT c.id, c.name
        FROM companies c
        JOIN medicines m ON m.company_id = c.id
        JOIN order_items oi ON oi.medicine_id = m.id
        ORDER BY c.name ASC
      ''');

      if (!mounted) return;
      setState(() {
        _months = monthRows.map((r) => r['m'] as String).toList();
        _allPharmacies = pharmacyRows
            .map((r) => FilterItem(r['id'] as int, r['name'] as String))
            .toList();
        _allCompanies = companyRows
            .map((r) => FilterItem(r['id'] as int, r['name'] as String))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Date helpers ────────────────────────────────────────────────────

  String _fmtDate(String? yyyyMmDd) {
    if (yyyyMmDd == null) return 'اختر تاريخ';
    try {
      final p = yyyyMmDd.split('-');
      return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {
      return yyyyMmDd;
    }
  }

  String _dateToStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_local.fromDate != null
            ? DateTime.parse(_local.fromDate!)
            : DateTime.now())
        : (_local.toDate != null
            ? DateTime.parse(_local.toDate!)
            : DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked == null || !mounted) return;

    final str = _dateToStr(picked);
    setState(() {
      _local = isFrom
          ? _local.copyWith(clearMonth: true, fromDate: str)
          : _local.copyWith(clearMonth: true, toDate: str);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _local = const OrderFilter()),
                      child: Text(
                        'مسح الكل',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'تصفية الطلبيات',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 80),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Body
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      // ── Month quick-select ────────────────────────────
                      if (_months.isNotEmpty) ...[
                        _sectionTitle('الشهر', theme),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _months.map((m) {
                              final selected = _local.month == m;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: Text(OrderFilter.monthLabel(m),
                                      style: const TextStyle(fontSize: 13)),
                                  selected: selected,
                                  selectedColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                  checkmarkColor: AppTheme.primaryColor,
                                  onSelected: (_) => setState(() {
                                    _local = selected
                                        ? _local.copyWith(clearMonth: true)
                                        : _local.copyWith(
                                            month: m,
                                            clearFromDate: true,
                                            clearToDate: true,
                                          );
                                  }),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Custom date range ─────────────────────────────
                      _sectionTitle('نطاق تاريخ مخصص', theme),
                      Row(
                        children: [
                          Expanded(
                            child: _dateButton(
                              label: _fmtDate(_local.fromDate),
                              hint: 'من',
                              onTap: () => _pickDate(isFrom: true),
                              theme: theme,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('←',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          Expanded(
                            child: _dateButton(
                              label: _fmtDate(_local.toDate),
                              hint: 'إلى',
                              onTap: () => _pickDate(isFrom: false),
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Pharmacies ────────────────────────────────────
                      if (_allPharmacies.isNotEmpty) ...[
                        _sectionTitle(
                          'الصيدليات  '
                          '(${_local.pharmacies.isEmpty ? 'الكل' : '${_local.pharmacies.length} محددة'})',
                          theme,
                        ),
                        ..._allPharmacies.map((p) {
                          final sel = _local.pharmacies.contains(p);
                          return _checkTile(
                            label: p.name,
                            value: sel,
                            onChanged: () {
                              final updated =
                                  List<FilterItem>.from(_local.pharmacies);
                              sel ? updated.remove(p) : updated.add(p);
                              setState(
                                  () => _local = _local.copyWith(pharmacies: updated));
                            },
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // ── Companies ──────────────────────────────────────
                      if (_allCompanies.isNotEmpty) ...[
                        _sectionTitle(
                          'الشركات  '
                          '(${_local.companies.isEmpty ? 'الكل' : '${_local.companies.length} محددة'})',
                          theme,
                        ),
                        ..._allCompanies.map((c) {
                          final sel = _local.companies.contains(c);
                          return _checkTile(
                            label: c.name,
                            value: sel,
                            onChanged: () {
                              final updated =
                                  List<FilterItem>.from(_local.companies);
                              sel ? updated.remove(c) : updated.add(c);
                              setState(
                                  () => _local = _local.copyWith(companies: updated));
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),

              // Apply button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _local),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    child: const Text('تطبيق التصفية',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────

  Widget _sectionTitle(String title, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          textDirection: TextDirection.rtl,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      );

  Widget _dateButton({
    required String label,
    required String hint,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final hasValue = label != 'اختر تاريخ';
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.calendar_today,
          size: 15,
          color: hasValue ? AppTheme.primaryColor : theme.colorScheme.outline),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hint,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      hasValue ? AppTheme.primaryColor : theme.colorScheme.onSurface
                          .withValues(alpha: 0.7))),
        ],
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        side: BorderSide(
            color: hasValue
                ? AppTheme.primaryColor.withValues(alpha: 0.6)
                : theme.colorScheme.outline.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _checkTile({
    required String label,
    required bool value,
    required VoidCallback onChanged,
  }) =>
      InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (_) => onChanged(),
                activeColor: AppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Text(
                  label,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
}


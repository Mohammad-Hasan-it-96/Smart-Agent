import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state.dart';
import 'daily_orders_screen.dart';
import 'order_filter.dart';
import 'order_filter_sheet.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Map<String, int> _ordersByDay = {};
  List<String> _sortedDays = [];
  bool _isLoading = true;

  /// Active filter — starts empty (no filtering).
  OrderFilter _filter = const OrderFilter();

  @override
  void initState() {
    super.initState();
    _loadOrdersByDay();
  }

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return '${parts[0]}/${parts[1]}/${parts[2]}';
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _loadOrdersByDay() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final (:where, :args) = _filter.buildGroupedWhere();
      final maps = await db.rawQuery('''
        SELECT
          SUBSTR(orders.created_at, 1, 10) AS order_date,
          COUNT(DISTINCT orders.id)        AS order_count
        FROM orders
        $where
        GROUP BY SUBSTR(orders.created_at, 1, 10)
        ORDER BY order_date DESC
      ''', args);

      final Map<String, int> ordersByDay = {};
      for (final map in maps) {
        final dateStr = map['order_date'] as String?;
        if (dateStr != null) {
          ordersByDay[dateStr] = map['order_count'] as int? ?? 0;
        }
      }
      setState(() {
        _ordersByDay = ordersByDay;
        _sortedDays =
            ordersByDay.keys.toList()..sort((a, b) => b.compareTo(a));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders by day: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      Navigator.push(
        context,
        SlidePageRoute(
          page: DailyOrdersScreen(date: picked, filter: _filter),
          direction: SlideDirection.rightToLeft,
        ),
      );
    }
  }

  void _navigateToDay(DateTime date) {
    Navigator.push(
      context,
      SlidePageRoute(
        page: DailyOrdersScreen(date: date, filter: _filter),
        direction: SlideDirection.rightToLeft,
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final newFilter = await showModalBottomSheet<OrderFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderFilterSheet(
        currentFilter: _filter,
        dbHelper: _dbHelper,
      ),
    );
    if (newFilter != null && mounted) {
      setState(() => _filter = newFilter);
      await _loadOrdersByDay();
    }
  }

  // ── Active filter chips ────────────────────────────────────────────

  Widget _buildActiveFilterChips(ThemeData theme) {
    if (!_filter.isActive) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (_filter.month != null) {
      chips.add(_chip('📅 ${OrderFilter.monthLabel(_filter.month!)}', theme));
    } else {
      if (_filter.fromDate != null) {
        chips.add(_chip('من ${_formatDisplayDate(_filter.fromDate!)}', theme));
      }
      if (_filter.toDate != null) {
        chips.add(_chip('إلى ${_formatDisplayDate(_filter.toDate!)}', theme));
      }
    }
    if (_filter.pharmacies.isNotEmpty) {
      chips.add(_chip('🏥 ${_filter.pharmacies.length} صيدلية', theme));
    }
    if (_filter.companies.isNotEmpty) {
      chips.add(_chip('🏢 ${_filter.companies.length} شركة', theme));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _filter = const OrderFilter());
              _loadOrdersByDay();
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('مسح', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Chip(
          label: Text(label,
              style: const TextStyle(fontSize: 12), textDirection: TextDirection.rtl),
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          labelStyle: const TextStyle(color: AppTheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomAppBar(
        title: 'الطلبيات',
        showNotifications: true,
        showSettings: true,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'تصفية',
                onPressed: _showFilterSheet,
              ),
              if (_filter.isActive)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrdersByDay,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active filter chips
                      _buildActiveFilterChips(theme),

                      // Date Picker Button
                      Card(
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Text(
                                  'اختر تاريخ',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Navigation Buttons
                      Text(
                        'أيام سريعة',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickDayButton('اليوم', DateTime.now(), theme),
                            const SizedBox(width: 8),
                            _buildQuickDayButton('أمس',
                                DateTime.now().subtract(const Duration(days: 1)), theme),
                            const SizedBox(width: 8),
                            _buildQuickDayButton('قبل يومين',
                                DateTime.now().subtract(const Duration(days: 2)), theme),
                            const SizedBox(width: 8),
                            _buildQuickDayButton('قبل ٣ أيام',
                                DateTime.now().subtract(const Duration(days: 3)), theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Grouped Orders by Day
                      if (_sortedDays.isEmpty)
                        EmptyState(
                          icon: Icons.receipt_long,
                          title: 'لا توجد طلبيات',
                          message: _filter.isActive
                              ? 'لا توجد طلبيات تطابق التصفية المحددة'
                              : 'لم يتم إنشاء أي طلبيات بعد',
                        )
                      else
                        ..._sortedDays.map((dayStr) {
                          final orderCount = _ordersByDay[dayStr] ?? 0;
                          DateTime dayDate;
                          try {
                            final parts = dayStr.split('-');
                            dayDate = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            );
                          } catch (_) {
                            dayDate = DateTime.now();
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _navigateToDay(dayDate),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$orderCount طلبية',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatDisplayDate(dayStr),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 20,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildQuickDayButton(String label, DateTime date, ThemeData theme) {
    return OutlinedButton(
      onPressed: () => _navigateToDay(date),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, color: theme.colorScheme.primary),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

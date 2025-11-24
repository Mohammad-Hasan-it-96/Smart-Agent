import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state.dart';
import 'order_details_screen.dart';

class DailyOrdersScreen extends StatefulWidget {
  final DateTime date;

  const DailyOrdersScreen({super.key, required this.date});

  @override
  State<DailyOrdersScreen> createState() => _DailyOrdersScreenState();
}

class _DailyOrdersScreenState extends State<DailyOrdersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDayDate(DateTime date) {
    // Return date in YYYY-MM-DD format to match ISO8601 date part
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadOrders(isInitialLoad: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoading &&
        _hasMoreData) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders({bool isInitialLoad = false}) async {
    if (_isLoading || (!_hasMoreData && !isInitialLoad)) return;

    setState(() {
      _isLoading = true;
      if (isInitialLoad) {
        _isInitialLoading = true;
        _currentPage = 0;
        _orders.clear();
      }
    });

    try {
      final db = await _dbHelper.database;

      // Format date for SQLite query (YYYY-MM-DD)
      final dateStr = _formatDayDate(widget.date);

      // Calculate offset
      final offset = _currentPage * _pageSize;

      // Query orders for the specific date with pagination
      // Use SUBSTR to extract first 10 characters (YYYY-MM-DD) from ISO8601 format
      // This works with strings like "2025-11-21T06:47:00.000Z"
      final maps = await db.rawQuery('''
        SELECT 
          orders.id,
          orders.pharmacy_id,
          orders.created_at,
          pharmacies.name as pharmacy_name,
          COUNT(order_items.id) as item_count
        FROM orders
        LEFT JOIN pharmacies ON orders.pharmacy_id = pharmacies.id
        LEFT JOIN order_items ON orders.id = order_items.order_id
        WHERE SUBSTR(orders.created_at, 1, 10) = ?
        GROUP BY orders.id
        ORDER BY orders.created_at DESC
        LIMIT ? OFFSET ?
      ''', [dateStr, _pageSize, offset]);

      if (mounted) {
        setState(() {
          if (isInitialLoad) {
            _orders = maps;
          } else {
            _orders.addAll(maps);
          }
          _hasMoreData = maps.length == _pageSize;
          _currentPage++;
          _isLoading = false;
          _isInitialLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _formatDayDate(widget.date);
    return Scaffold(
      appBar: CustomAppBar(
        title: 'طلبيات ${dateStr.replaceAll('-', '/')}',
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'لا توجد طلبيات',
                  message: 'لا توجد طلبيات في هذا التاريخ',
                )
              : RefreshIndicator(
                  onRefresh: () => _loadOrders(isInitialLoad: true),
                  child: SafeArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _orders.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final order = _orders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                SlidePageRoute(
                                  page: OrderDetailsScreen(
                                    orderId: order['id'] as int,
                                  ),
                                  direction: SlideDirection.rightToLeft,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long,
                                      size: 28,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['pharmacy_name'] ??
                                              'صيدلية غير معروفة',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDate(order['created_at']
                                                  as String),
                                              style: theme.textTheme.bodyMedium,
                                              textDirection: TextDirection.rtl,
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(
                                              Icons.shopping_cart,
                                              size: 16,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${order['item_count'] ?? 0} عنصر',
                                              style: theme.textTheme.bodyMedium,
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                        ),
                                      ],
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
                      },
                    ),
                  ),
                ),
    );
  }
}

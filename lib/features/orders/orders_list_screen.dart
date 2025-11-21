import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/utils/slide_page_route.dart';
import 'daily_orders_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Map<String, int> _ordersByDay = {}; // Map of date string to order count
  List<String> _sortedDays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrdersByDay();
  }

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _loadOrdersByDay() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _dbHelper.database;

      // First, let's check what's actually in the database
      final allOrders = await db.rawQuery('''
        SELECT id, created_at, SUBSTR(created_at, 1, 10) as date_part
        FROM orders
        LIMIT 10
      ''');
      print('Sample orders in database:');
      for (var row in allOrders) {
        print(
            '  Order ID: ${row['id']}, Date part: ${row['date_part']}, Full: ${row['created_at']}');
      }

      // Get orders grouped by day with count
      // Use SUBSTR to extract date part from ISO8601 format (YYYY-MM-DDTHH:mm:ss...)
      final maps = await db.rawQuery('''
        SELECT 
          SUBSTR(orders.created_at, 1, 10) as order_date,
          COUNT(DISTINCT orders.id) as order_count
        FROM orders
        GROUP BY SUBSTR(orders.created_at, 1, 10)
        ORDER BY order_date DESC
      ''');

      final Map<String, int> ordersByDay = {};
      for (final map in maps) {
        final dateStr = map['order_date'] as String?;
        if (dateStr != null) {
          ordersByDay[dateStr] = map['order_count'] as int? ?? 0;
        }
      }

      setState(() {
        _ordersByDay = ordersByDay;
        _sortedDays = ordersByDay.keys.toList()..sort((a, b) => b.compareTo(a));
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders by day: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      Navigator.push(
        context,
        SlidePageRoute(
          page: DailyOrdersScreen(date: picked),
          direction: SlideDirection.rightToLeft,
        ),
      );
    }
  }

  void _navigateToDay(DateTime date) {
    Navigator.push(
      context,
      SlidePageRoute(
        page: DailyOrdersScreen(date: date),
        direction: SlideDirection.rightToLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبيات السابقة'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrdersByDay,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date Picker Button
                    Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'اختر تاريخ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Navigation Buttons
                    const Text(
                      'أيام سريعة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickDayButton(
                            'اليوم',
                            DateTime.now(),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickDayButton(
                            'أمس',
                            DateTime.now().subtract(const Duration(days: 1)),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickDayButton(
                            'قبل يومين',
                            DateTime.now().subtract(const Duration(days: 2)),
                          ),
                          const SizedBox(width: 8),
                          _buildQuickDayButton(
                            'قبل ٣ أيام',
                            DateTime.now().subtract(const Duration(days: 3)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Grouped Orders by Day
                    if (_sortedDays.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'لا توجد طلبيات',
                            style: TextStyle(fontSize: 18),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
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
                        } catch (e) {
                          dayDate = DateTime.now();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _navigateToDay(dayDate),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
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
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$orderCount طلبية',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                  Text(
                                    _formatDisplayDate(dayStr),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  const Icon(
                                    Icons.arrow_back_ios,
                                    size: 20,
                                    textDirection: TextDirection.rtl,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickDayButton(String label, DateTime date) {
    return ElevatedButton(
      onPressed: () => _navigateToDay(date),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

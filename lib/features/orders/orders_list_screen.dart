import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _dbHelper.database;
      // Get orders with pharmacy name and item count
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
        GROUP BY orders.id
        ORDER BY orders.created_at DESC
      ''');

      setState(() {
        _orders = maps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
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
          : _orders.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد طلبيات',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, size: 32),
                          title: Text(
                            order['pharmacy_name'] ?? 'صيدلية غير معروفة',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'التاريخ: ${_formatDate(order['created_at'] as String)}',
                                style: const TextStyle(fontSize: 14),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'عدد العناصر: ${order['item_count'] ?? 0}',
                                style: const TextStyle(fontSize: 14),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_back_ios, size: 16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailsScreen(
                                  orderId: order['id'] as int,
                                ),
                              ),
                            );
                            // Refresh list after returning
                            _loadOrders();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

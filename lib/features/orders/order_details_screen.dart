import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/db/database_helper.dart';
import 'pdf_exporter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _orderInfo;
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _dbHelper.database;

      // Get order info with pharmacy details
      final orderMaps = await db.rawQuery('''
        SELECT 
          orders.id,
          orders.pharmacy_id,
          orders.created_at,
          pharmacies.name as pharmacy_name,
          pharmacies.address as pharmacy_address,
          pharmacies.phone as pharmacy_phone
        FROM orders
        LEFT JOIN pharmacies ON orders.pharmacy_id = pharmacies.id
        WHERE orders.id = ?
      ''', [widget.orderId]);

      if (orderMaps.isNotEmpty) {
        _orderInfo = orderMaps.first;
      }

      // Get order items with medicine and company details
      final itemMaps = await db.rawQuery('''
        SELECT 
          order_items.id,
          order_items.order_id,
          order_items.medicine_id,
          order_items.qty,
          medicines.name as medicine_name,
          companies.name as company_name
        FROM order_items
        LEFT JOIN medicines ON order_items.medicine_id = medicines.id
        LEFT JOIN companies ON medicines.company_id = companies.id
        WHERE order_items.order_id = ?
        ORDER BY medicines.name
      ''', [widget.orderId]);

      setState(() {
        _orderItems = itemMaps;
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

  Future<void> _exportToPdf() async {
    if (_orderInfo == null) {
      return;
    }

    try {
      // Prepare pharmacy data
      final pharmacy = {
        'pharmacy_name': _orderInfo!['pharmacy_name'],
        'pharmacy_address': _orderInfo!['pharmacy_address'],
        'pharmacy_phone': _orderInfo!['pharmacy_phone'],
      };

      // Generate PDF
      final pdfBytes = await generateOrderPdf(
        _orderInfo!,
        _orderItems,
        pharmacy,
      );

      // Share PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'order_${widget.orderId}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير PDF بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلبية'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderInfo == null
              ? const Center(
                  child: Text('لم يتم العثور على الطلبية'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'معلومات الطلبية',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'الصيدلية',
                                _orderInfo!['pharmacy_name'] ?? 'غير معروف',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'العنوان',
                                _orderInfo!['pharmacy_address'] ?? 'غير معروف',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'الهاتف',
                                _orderInfo!['pharmacy_phone'] ?? 'غير معروف',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'التاريخ',
                                _formatDate(
                                    _orderInfo!['created_at'] as String),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Order Items
                      const Text(
                        'عناصر الطلبية',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 16),

                      _orderItems.isEmpty
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'لا توجد عناصر',
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            )
                          : Card(
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(1),
                                },
                                children: [
                                  // Header
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                    ),
                                    children: const [
                                      TableCell(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'الدواء',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'الشركة',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'الكمية',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Data rows
                                  ...List.generate(_orderItems.length, (index) {
                                    final item = _orderItems[index];
                                    return TableRow(
                                      children: [
                                        TableCell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              item['medicine_name'] ??
                                                  'غير معروف',
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              item['company_name'] ??
                                                  'غير معروف',
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              item['qty'].toString(),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),

                      // Export PDF Button
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _exportToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text(
                          'تصدير PDF',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}

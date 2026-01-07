import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../core/db/database_helper.dart';
import '../../core/services/settings_service.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'pdf_exporter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SettingsService _settingsService = SettingsService();
  Map<String, dynamic>? _orderInfo;
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;
  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  double _exchangeRate = 1.0;
  String _inventoryPhone = '';

  static const MethodChannel _whatsAppChannel =
      MethodChannel('smart_agent/whatsapp_share');

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
    _loadOrderDetails();
  }

  Future<void> _loadPricingSettings() async {
    final enabled = await _settingsService.isPricingEnabled();
    final mode = await _settingsService.getCurrencyMode();
    final rate = await _settingsService.getExchangeRate();
    final inventoryPhone = await _settingsService.getInventoryPhone();
    setState(() {
      _pricingEnabled = enabled;
      _currencyMode = mode;
      _exchangeRate = rate;
      _inventoryPhone = inventoryPhone;
    });
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
      // Use price from medicines table (fallback to order_items.price for backward compatibility)
      final itemMaps = await db.rawQuery('''
        SELECT 
          order_items.id,
          order_items.order_id,
          order_items.medicine_id,
          order_items.qty,
          COALESCE(medicines.price_usd, order_items.price, 0) as price_usd,
          medicines.name as medicine_name,
          medicines.source as medicine_source,
          medicines.form as medicine_form,
          medicines.notes as medicine_notes,
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

  /// Share order PDF directly to WhatsApp chat with inventory phone
  Future<void> _shareWithInventory() async {
    if (_orderInfo == null) return;
    final phone = _inventoryPhone.trim();
    if (phone.isEmpty) return;

    if (!Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مشاركة الواتساب مدعومة على أجهزة أندرويد فقط.'),
          ),
        );
      }
      return;
    }

    try {
      // Prepare pharmacy data
      final pharmacy = {
        'pharmacy_name': _orderInfo!['pharmacy_name'],
        'pharmacy_address': _orderInfo!['pharmacy_address'],
        'pharmacy_phone': _orderInfo!['pharmacy_phone'],
      };

      // Generate PDF bytes
      final pdfBytes = await generateOrderPdf(
        _orderInfo!,
        _orderItems,
        pharmacy,
      );

      // Save PDF to a temporary file so it can be shared via FileProvider
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/order_${widget.orderId}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      try {
        await _whatsAppChannel.invokeMethod('sharePdfToWhatsApp', {
          'filePath': file.path,
          'phone': phone,
          'message': 'هذه الطلبية الخاصة بالصيدلية',
        });
      } on PlatformException catch (e) {
        if (!mounted) return;
        if (e.code == 'WHATSAPP_NOT_INSTALLED' ||
            e.code == 'WHATSAPP_NOT_AVAILABLE') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                'تنبيه',
                textDirection: TextDirection.rtl,
              ),
              content: const Text(
                'تعذّر فتح واتساب للمشاركة على هذا الجهاز.\n'
                'تأكد من تثبيت واتساب وتحديثه ثم أعد المحاولة.',
                textDirection: TextDirection.rtl,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('تعذّر مشاركة الطلبية عبر واتساب. يرجى المحاولة مرة أخرى.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('حدث خطأ غير متوقع أثناء مشاركة الطلبية. يرجى المحاولة لاحقاً.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'تفاصيل الطلبية'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderInfo == null
              ? const Center(
                  child: Text('لم يتم العثور على الطلبية'),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Order Info Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'معلومات الطلبية',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(height: 20),
                                _buildInfoRow(
                                  'الصيدلية',
                                  _orderInfo!['pharmacy_name'] ?? 'غير معروف',
                                  theme,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'العنوان',
                                  _orderInfo!['pharmacy_address'] ??
                                      'غير معروف',
                                  theme,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'الهاتف',
                                  _orderInfo!['pharmacy_phone'] ?? 'غير معروف',
                                  theme,
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'التاريخ',
                                  _formatDate(
                                      _orderInfo!['created_at'] as String),
                                  theme,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Order Items
                        Text(
                          'عناصر الطلبية',
                          style: theme.textTheme.titleLarge?.copyWith(
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
                            : Column(
                                children:
                                    List.generate(_orderItems.length, (index) {
                                  final item = _orderItems[index];
                                  final itemNumber =
                                      index + 1; // 1-based numbering
                                  // Use price_usd from medicine record (fallback to order_items.price for backward compatibility)
                                  final priceUsd =
                                      (item['price_usd'] as num?)?.toDouble() ??
                                          (item['price'] as num?)?.toDouble() ??
                                          0.0;
                                  double displayPrice = priceUsd;
                                  if (_pricingEnabled &&
                                      _currencyMode == 'syp') {
                                    displayPrice = priceUsd * _exchangeRate;
                                  }
                                  final qty =
                                      (item['qty'] as num?)?.toInt() ?? 0;
                                  final total = displayPrice * qty;
                                  final currencySymbol =
                                      _currencyMode == 'syp' ? 'ل.س' : '\$';

                                  final medicineName =
                                      item['medicine_name'] ?? 'غير معروف';
                                  final companyName =
                                      item['company_name'] ?? 'غير معروف';
                                  final source =
                                      item['medicine_source'] as String?;
                                  final form = item['medicine_form'] as String?;
                                  final notes =
                                      item['medicine_notes'] as String?;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Item number and medicine name row
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            textDirection: TextDirection.rtl,
                                            children: [
                                              // Medicine name (bold)
                                              Expanded(
                                                child: Text(
                                                  medicineName,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textDirection:
                                                      TextDirection.rtl,
                                                ),
                                              ),
                                              // Item number
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme
                                                      .primaryContainer,
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  itemNumber.toString(),
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme
                                                        .onPrimaryContainer,
                                                  ),
                                                  textDirection:
                                                      TextDirection.rtl,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Company name
                                          Text(
                                            'الشركة: $companyName',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                          // Source (if available)
                                          if (source != null &&
                                              source.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'المصدر: $source',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                          // Form (if available)
                                          if (form != null &&
                                              form.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'النوع: $form',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                          // Notes (if available)
                                          if (notes != null &&
                                              notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'ملاحظات: $notes',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          // Quantity and price
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'الكمية: $qty',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textDirection:
                                                    TextDirection.rtl,
                                              ),
                                              if (_pricingEnabled)
                                                Text(
                                                  '${displayPrice.toStringAsFixed(2)} $currencySymbol × $qty = ${total.toStringAsFixed(2)} $currencySymbol',
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                                  textDirection:
                                                      TextDirection.rtl,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),

                        // Total (if pricing enabled)
                        if (_pricingEnabled && _orderItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Card(
                            color: theme.colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _calculateTotal(),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  Text(
                                    'المجموع النهائي:',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Export / Share Buttons
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _exportToPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text(
                            'تصدير PDF',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        if (_inventoryPhone.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _shareWithInventory,
                            icon: const Icon(Icons.share),
                            label: const Text(
                              'مشاركة مع المستودع',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  String _calculateTotal() {
    double totalUsd = 0.0;
    for (final item in _orderItems) {
      // Use price_usd from medicine record (fallback to order_items.price for backward compatibility)
      final priceUsd = (item['price_usd'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          0.0;
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      totalUsd += priceUsd * qty;
    }

    double displayTotal = totalUsd;
    if (_currencyMode == 'syp') {
      displayTotal = totalUsd * _exchangeRate;
    }

    final currencySymbol = _currencyMode == 'syp' ? 'ل.س' : '\$';
    return '${displayTotal.toStringAsFixed(2)} $currencySymbol';
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db/database_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/bluetooth_print_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/models/warehouse.dart';
import 'new_order_screen.dart';
import 'pdf_exporter.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SettingsService _settingsService = getIt<SettingsService>();
  Map<String, dynamic>? _orderInfo;
  List<Map<String, dynamic>> _orderItems = [];
  List<Map<String, dynamic>> _giftOrderItems = [];
  bool _isLoading = true;
  bool _isPrinting = false;
  bool _pricingEnabled = false;
  String _currencyMode = 'usd';
  double _exchangeRate = 1.0;
    List<Warehouse> _warehouses = [];

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
    final warehouseList = await _settingsService.getWarehouseList();
    setState(() {
      _pricingEnabled = enabled;
      _currencyMode = mode;
      _exchangeRate = rate;
      _warehouses = warehouseList.where((w) => w.isFilled).toList();
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
          orders.invoice_number,
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
          CASE 
            WHEN order_items.is_gift = 1 THEN 0 
            ELSE COALESCE(medicines.price_usd, order_items.price, 0) 
          END as price_usd,
          medicines.price_syp as price_syp,
          order_items.price as price,
          order_items.is_gift as is_gift,
          order_items.gift_qty as gift_qty,
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

      // Load gift items
      final giftMaps = await db.rawQuery('''
        SELECT ogi.id, ogi.qty, g.name AS gift_name, g.notes AS gift_notes
        FROM order_gift_items ogi
        LEFT JOIN gifts g ON ogi.gift_id = g.id
        WHERE ogi.order_id = ?
        ORDER BY g.name
      ''', [widget.orderId]);

      if (mounted) {
        setState(() => _giftOrderItems = giftMaps);
      }
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


  /// Share PDF to a specific phone number via WhatsApp
  Future<void> _sharePdfToPhone(String phone) async {
    if (_orderInfo == null) return;
    final normalized = normalizePhone(phone.trim());
    if (normalized == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم المستودع غير صالح.')),
        );
      }
      return;
    }
    if (!Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مشاركة ملف PDF مدعومة على أجهزة أندرويد فقط.')),
        );
      }
      return;
    }
    try {
      final pharmacy = {
        'pharmacy_name': _orderInfo!['pharmacy_name'],
        'pharmacy_address': _orderInfo!['pharmacy_address'],
        'pharmacy_phone': _orderInfo!['pharmacy_phone'],
      };
      final pdfBytes = await generateOrderPdf(_orderInfo!, _orderItems, pharmacy);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/order_${widget.orderId}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);
      await _whatsAppChannel.invokeMethod('sharePdfToWhatsApp', {
        'filePath': file.path,
        'phone': normalized,
        'message': 'طلبية صيدلية ${_orderInfo!['pharmacy_name'] ?? ''}',
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'WHATSAPP_NOT_INSTALLED' || e.code == 'WHATSAPP_NOT_AVAILABLE') {
        showWhatsAppUnavailableDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر مشاركة الطلبية عبر واتساب.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع أثناء مشاركة الطلبية.')),
        );
      }
    }
  }

  /// Send text order summary to a specific phone via WhatsApp
  Future<void> _sendTextToPhone(String phone) async {
    if (_orderInfo == null) return;
    final normalized = normalizePhone(phone.trim());
    if (normalized == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم المستودع غير صالح.')),
        );
      }
      return;
    }
    final agentName = await getIt<ActivationService>().getAgentName();
    final currencySymbol = _currencyMode == 'syp' ? 'ل.س' : '\$';
    final message = buildOrderMessage(
      pharmacyName: _orderInfo!['pharmacy_name'] ?? 'غير معروف',
      representativeName: agentName,
      orderId: widget.orderId,
      orderDate: _formatDate(_orderInfo!['created_at'] as String),
      items: _orderItems,
      pricingEnabled: _pricingEnabled,
      currencySymbol: currencySymbol,
      currencyMode: _currencyMode,
      exchangeRate: _exchangeRate,
    );
    final success = await openWhatsAppChat(phone: phone.trim(), message: message);
    if (!success && mounted) {
      showWhatsAppUnavailableDialog(context);
    }
  }

  // ── Bluetooth printing ──────────────────────────────────────────────────

  /// Shows a one-time explanation dialog about the Nearby Devices / Bluetooth
  /// permission before the first print attempt.
  ///
  /// Returns `true` when the user confirms and printing should continue.
  /// Returns `false` when the user cancels and the flow should be aborted.
  Future<bool> _ensureBluetoothExplained() async {
    const _kExplainedKey = 'bt_permission_explained';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kExplainedKey) == true) return true; // already shown

    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.bluetooth_searching_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'الطباعة عبر البلوتوث',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'لاكتشاف الطابعة والاتصال بها، يحتاج التطبيق إلى صلاحية "الأجهزة القريبة" (Nearby Devices).\n\n'
          'في الأجهزة التي تعمل بنظام Android 12 أو أحدث، ستظهر هذه الصلاحية باسم "الأجهزة القريبة"، وهو أمر طبيعي ومتوقع.\n\n'
          'اضغط "موافق" للمتابعة والسماح بالصلاحية عند الطلب.',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 14, height: 1.55),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    final ok = confirmed == true;
    if (ok) await prefs.setBool(_kExplainedKey, true);
    return ok;
  }

  Future<void> _printOrder() async {
    if (_orderInfo == null || _isPrinting) return;

    // ── 0. Show one-time Bluetooth permission explanation ─────────────────
    final proceed = await _ensureBluetoothExplained();
    if (!proceed || !mounted) return;

    setState(() => _isPrinting = true);

    final btService = getIt<BluetoothPrintService>();
    BtPrinterDevice? deviceToUse;
    bool wasAutoConnected = false;

    // ── 1. Try silent auto-connect to the last-used printer ───────────────
    final autoOk = await btService.connectToPreferred();
    if (!mounted) {
      setState(() => _isPrinting = false);
      return;
    }

    if (autoOk) {
      deviceToUse = btService.connectedDevice;
      wasAutoConnected = true;
    } else {
      // ── 2. Fall back to manual selection ─────────────────────────────────
      final devices = await btService.getPairedDevices();
      final preferredAddress =
          (await btService.loadPreferredPrinter())?.address;

      if (!mounted) {
        setState(() => _isPrinting = false);
        return;
      }

      if (devices.isEmpty) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا توجد طابعات بلوتوث مقترنة. يرجى إقران الطابعة أولاً من إعدادات الجهاز.\n'
              'إذا رفضت صلاحية "الأجهزة القريبة"، يرجى تفعيلها من إعدادات التطبيق.',
              textDirection: TextDirection.rtl,
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      deviceToUse = await showDialog<BtPrinterDevice>(
        context: context,
        builder: (ctx) => _PrinterSelectionDialog(
          devices: devices,
          preferredAddress: preferredAddress,
        ),
      );

      if (deviceToUse == null || !mounted) {
        setState(() => _isPrinting = false);
        return;
      }
    }

    // ── 3. Show progress dialog ───────────────────────────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrintingProgressDialog(),
    );

    // ── 4. Connect (if not already auto-connected) ────────────────────────
    if (!wasAutoConnected) {
      final connected = await btService.connect(deviceToUse!);
      if (!mounted) return;
      if (!connected) {
        Navigator.of(context).pop();
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر الاتصال بـ "${deviceToUse.name}"',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
        return;
      }
      // Save as preferred for next time
      await btService.savePreferredPrinter(deviceToUse);
    }

    // ── 5. Print then disconnect ──────────────────────────────────────────
    try {
      final agentName = await getIt<ActivationService>().getAgentName();
      if (!mounted) return;

      await btService.printOrderInvoice(
        pharmacyName: (_orderInfo!['pharmacy_name'] as String?) ?? 'غير معروف',
        orderDate: _formatDate(_orderInfo!['created_at'] as String),
        items: _orderItems,
        giftOrderItems: _giftOrderItems,
        agentName: agentName,
        invoiceNumber: _orderInfo!['invoice_number'] as String?,
      );
      await btService.disconnect();

      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت الطباعة بنجاح ✓  (${deviceToUse?.name ?? ''})',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } catch (e) {
      await btService.disconnect();
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطأ أثناء الطباعة: $e',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  // ── Edit order ─────────────────────────────────────────────────────

  Future<void> _editOrder() async {
    final result = await Navigator.push<bool>(
      context,
      SlidePageRoute(
        page: NewOrderScreen(editOrderId: widget.orderId),
        direction: SlideDirection.rightToLeft,
      ),
    );
    // Reload details if the edit was saved
    if (result == true && mounted) {
      _loadOrderDetails();
    }
  }

  // ── Delete order ────────────────────────────────────────────────────

  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(
            'حذف الطلبية',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هل أنت متأكد من حذف هذه الطلبية؟\nلا يمكن التراجع عن هذا الإجراء.',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      // Delete items first (child rows), then the order (parent row)
      await _dbHelper.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [widget.orderId],
      );
      await _dbHelper.delete(
        'orders',
        where: 'id = ?',
        whereArgs: [widget.orderId],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطلبية بنجاح')),
        );
        // Pop with true so the caller (DailyOrdersScreen) can refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حذف الطلبية: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomAppBar(
        title: 'تفاصيل الطلبية',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل الطلبية',
            onPressed: _orderInfo == null || _isLoading ? null : _editOrder,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'حذف الطلبية',
            onPressed: _orderInfo == null || _isLoading ? null : _deleteOrder,
          ),
        ],
      ),
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
                                if (((_orderInfo!['pharmacy_address'] as String?)
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)) ...[
                                  _buildInfoRow(
                                    'العنوان',
                                    (_orderInfo!['pharmacy_address'] as String)
                                        .trim(),
                                    theme,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (((_orderInfo!['pharmacy_phone'] as String?)
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)) ...[
                                  _buildInfoRow(
                                    'الهاتف',
                                    (_orderInfo!['pharmacy_phone'] as String)
                                        .trim(),
                                    theme,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _buildInfoRow(
                                  'التاريخ',
                                  _formatDate(
                                      _orderInfo!['created_at'] as String),
                                  theme,
                                ),
                                if ((_orderInfo!['invoice_number'] as String?)?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    'رقم الفاتورة',
                                    _orderInfo!['invoice_number'] as String,
                                    theme,
                                  ),
                                ],
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
                                  final displayPrice = _resolveUnitPrice(item);
                                  final qty =
                                      (item['qty'] as num?)?.toInt() ?? 0;
                                  final giftQty =
                                      (item['gift_qty'] as num?)?.toInt() ?? 0;
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
                                  final isGiftOnly =
                                      (item['is_gift'] as int? ?? 0) == 1;

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
                                          if (isGiftOnly || giftQty > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              giftQty > 0
                                                  ? 'هدية: $giftQty'
                                                  : 'هدية',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
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
                                              if (_pricingEnabled &&
                                                  !isGiftOnly)
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

                        // Gift order items section
                        if (_giftOrderItems.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'الهدايا',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: List.generate(_giftOrderItems.length, (i) {
                              final g = _giftOrderItems[i];
                              final giftName = (g['gift_name'] as String?) ?? 'غير معروف';
                              final giftNotes = g['gift_notes'] as String?;
                              final qty = (g['qty'] as num?)?.toInt() ?? 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.teal),
                                  ),
                                  title: Text(giftName, style: const TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
                                  subtitle: (giftNotes ?? '').isNotEmpty
                                      ? Text(giftNotes!, textDirection: TextDirection.rtl)
                                      : null,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('× $qty', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],

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
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: (_isLoading || _orderInfo == null || _isPrinting)
                              ? null
                              : _printOrder,
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print_rounded),
                          label: Text(
                            _isPrinting ? 'جارٍ الطباعة...' : 'طباعة بلوتوث',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.teal,
                          ),
                        ),
                        // ── Unified warehouse quick actions ──
                        if (_warehouses.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          if (_pricingEnabled && _hasMissingSelectedCurrencyPrice()) ...[
                            Card(
                              color: theme.colorScheme.secondaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  'بعض الأدوية لا تملك سعرًا بالعملة المحددة، لذلك تم استخدام سعر بديل بشكل آمن.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rocket_launch_rounded,
                                  size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'مشاركة سريعة مع المستودعات',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final wh in _warehouses)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      wh.name,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      textDirection: TextDirection.rtl,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _sharePdfToPhone(wh.phone),
                                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                                            label: const Text('PDF', style: TextStyle(fontSize: 13)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _sendTextToPhone(wh.phone),
                                            icon: const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                                            label: const Text('رسالة', style: TextStyle(fontSize: 13)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              foregroundColor: const Color(0xFF25D366),
                                              side: const BorderSide(color: Color(0xFF25D366)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
    double total = 0.0;
    for (final item in _orderItems) {
      final isGiftOnly = (item['is_gift'] as int? ?? 0) == 1;
      if (isGiftOnly) continue;
      final unitPrice = _resolveUnitPrice(item);
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      total += unitPrice * qty;
    }

    final currencySymbol = _currencyMode == 'syp' ? 'ل.س' : '\$';
    return '${total.toStringAsFixed(2)} $currencySymbol';
  }

  double _resolveUnitPrice(Map<String, dynamic> item) {
    final priceUsd = (item['price_usd'] as num?)?.toDouble();
    final priceSyp = (item['price_syp'] as num?)?.toDouble();
    final fallbackPrice = (item['price'] as num?)?.toDouble() ?? 0.0;

    if (_currencyMode == 'syp') {
      if ((priceSyp ?? 0) > 0) return priceSyp!;
      if ((priceUsd ?? 0) > 0) return priceUsd!;
      return fallbackPrice;
    }

    if ((priceUsd ?? 0) > 0) return priceUsd!;
    if ((priceSyp ?? 0) > 0) return priceSyp!;
    return fallbackPrice;
  }

  bool _hasMissingSelectedCurrencyPrice() {
    for (final item in _orderItems) {
      final priceUsd = (item['price_usd'] as num?)?.toDouble();
      final priceSyp = (item['price_syp'] as num?)?.toDouble();
      if (_currencyMode == 'syp') {
        if ((priceSyp ?? 0) <= 0 && (priceUsd ?? 0) > 0) return true;
      } else {
        if ((priceUsd ?? 0) <= 0 && (priceSyp ?? 0) > 0) return true;
      }
    }
    return false;
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

// ── Private helper widgets ───────────────────────────────────────────────────

/// Dialog that lists paired BT devices and returns the user's choice.
/// The previously-used printer is highlighted with a ★ badge.
class _PrinterSelectionDialog extends StatelessWidget {
  const _PrinterSelectionDialog({
    required this.devices,
    this.preferredAddress,
  });

  final List<BtPrinterDevice> devices;

  /// MAC address of the last-used printer (may be null).
  final String? preferredAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.print_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('اختر الطابعة', textDirection: TextDirection.rtl),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = devices[i];
            final isPreferred = d.address == preferredAddress;
            return ListTile(
              leading: Icon(
                isPreferred ? Icons.print_rounded : Icons.print_outlined,
                color: isPreferred
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(d.name, textDirection: TextDirection.rtl),
              subtitle: Text(
                isPreferred
                    ? '${d.address}  ★ آخر طابعة مستخدمة'
                    : d.address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isPreferred ? theme.colorScheme.primary : null,
                ),
              ),
              onTap: () => Navigator.of(context).pop(d),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

/// Non-dismissible progress dialog shown while connecting + printing.
class _PrintingProgressDialog extends StatelessWidget {
  const _PrintingProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'جارٍ الاتصال والطباعة...',
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


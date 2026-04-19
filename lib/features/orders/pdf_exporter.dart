import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/db/database_helper.dart';

Future<Uint8List> generateOrderPdf(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> items,
  Map<String, dynamic> pharmacy, {
  List<Map<String, dynamic>> giftOrderItems = const [],
}) async {
  // If items list is empty, try to fetch from database
  // This handles cases where order object doesn't have items loaded
  if (items.isEmpty && order['id'] != null) {
    try {
      final dbHelper = DatabaseHelper.instance;
      final orderId = order['id'] as int;
      items = await dbHelper.fetchOrderItemsWithDetails(orderId);
    } catch (e) {
      // If DB fetch fails, continue with empty items list
      debugPrint('Warning: Could not fetch items from DB: $e');
    }
  }

  // Fetch gift order items from DB if not provided
  if (giftOrderItems.isEmpty && order['id'] != null) {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      giftOrderItems = await db.rawQuery('''
        SELECT ogi.qty, g.name AS gift_name, g.notes AS gift_notes
        FROM order_gift_items ogi
        LEFT JOIN gifts g ON ogi.gift_id = g.id
        WHERE ogi.order_id = ?
        ORDER BY g.name
      ''', [order['id'] as int]);
    } catch (e) {
      debugPrint('Warning: Could not fetch gift items from DB: $e');
    }
  }
  // Load Arabic font
  pw.Font? arabicFont;
  try {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    arabicFont = pw.Font.ttf(fontData);
  } catch (e) {
    // If font file is not found, PDF will use default font
    // This allows the PDF to still generate even without the Arabic font
    debugPrint('Warning: Arabic font not found. Using default font. Error: $e');
    debugPrint('Please ensure Cairo-Regular.ttf is placed in assets/fonts/');
  }

  // Create text style with Arabic font
  pw.TextStyle getArabicStyle({
    // Slightly smaller default for better A4 fit
    double fontSize = 10,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
  }) {
    return pw.TextStyle(
      font: arabicFont, // Will be null if font not loaded, using default
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  // Get agent data via DI
  final activationService = getIt<ActivationService>();
  final agentName = await activationService.getAgentName();
  final agentPhone = await activationService.getAgentPhone();

  // Get pricing settings via DI
  final settingsService = getIt<SettingsService>();
  final pricingEnabled = await settingsService.isPricingEnabled();
  final currencyMode = await settingsService.getCurrencyMode();
  final currencySymbol = currencyMode == 'syp' ? 'ل.س' : '\$';

  final pdf = pw.Document();
  final pageWidth = PdfPageFormat.a4.width;
  const itemsPerPage = 20;

  // Split items into chunks for pagination
  final List<List<Map<String, dynamic>>> itemChunks = [];
  for (int i = 0; i < items.length; i += itemsPerPage) {
    itemChunks.add(items.sublist(
      i,
      i + itemsPerPage > items.length ? items.length : i + itemsPerPage,
    ));
  }

  // If no items, create a single empty chunk
  if (itemChunks.isEmpty) {
    itemChunks.add([]);
  }

  // Build header content (title + agent/pharmacy info) - shown on first page only
  pw.Widget buildHeader() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title
          pw.Center(
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                pricingEnabled
                    ? 'المندوب الذكي - فاتورة مبيع'
                    : 'المندوب الذكي - طلبية',
                style: getArabicStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // Agent Info and Pharmacy Info side-by-side (compact)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Agent Info (if available) - compact
              if (agentName.isNotEmpty || agentPhone.isNotEmpty)
                pw.Container(
                  width: pageWidth * 0.43,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'معلومات المندوب',
                          style: getArabicStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (agentName.isNotEmpty)
                          pw.Text(
                            'اسم المندوب: $agentName',
                            style: getArabicStyle(fontSize: 8.5),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        if (agentName.isNotEmpty && agentPhone.isNotEmpty)
                          pw.SizedBox(height: 2),
                        if (agentPhone.isNotEmpty)
                          pw.Text(
                            'رقم المندوب: $agentPhone',
                            style: getArabicStyle(fontSize: 8.5),
                            textDirection: pw.TextDirection.rtl,
                          ),
                      ],
                    ),
                  ),
                )
              else
                pw.SizedBox(width: pageWidth * 0.43),

              // Pharmacy Info - compact
              pw.Container(
                width: pageWidth * 0.43,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'معلومات الصيدلية',
                        style: getArabicStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'الاسم: ${pharmacy['pharmacy_name'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 8.5),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      if ((pharmacy['pharmacy_address'] as String?)
                              ?.trim()
                              .isNotEmpty ??
                          false) ...[
                        pw.Text(
                          'العنوان: ${(pharmacy['pharmacy_address'] as String).trim()}',
                          style: getArabicStyle(fontSize: 8.5),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      if ((pharmacy['pharmacy_phone'] as String?)
                              ?.trim()
                              .isNotEmpty ??
                          false) ...[
                        pw.Text(
                          'الهاتف: ${(pharmacy['pharmacy_phone'] as String).trim()}',
                          style: getArabicStyle(fontSize: 8.5),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      pw.Text(
                        'التاريخ: ${_formatDate(order['created_at'] as String)}',
                        style: getArabicStyle(fontSize: 8.5),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      if ((order['invoice_number'] as String?)?.isNotEmpty ?? false) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'رقم الفاتورة: ${order['invoice_number']}',
                          style: getArabicStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  // Build items table for a chunk of items
  pw.Widget buildItemsTable(
      List<Map<String, dynamic>> chunkItems, int startIndex) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'عناصر الطلبية',
            style: getArabicStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 8),
          chunkItems.isEmpty
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text(
                      'لا توجد عناصر في هذه الطلبية',
                      style: getArabicStyle(fontSize: 10),
                    ),
                  ),
                )
              : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: pricingEnabled
                      ? {
                          // Reversed for RTL visual reading: المجموع, السعر, هدية, الكمية, الشركة, الدواء, الرقم
                          0: const pw.FlexColumnWidth(1.5), // المجموع
                          1: const pw.FlexColumnWidth(1.5), // السعر
                          2: const pw.FlexColumnWidth(1), // هدية
                          3: const pw.FlexColumnWidth(1), // الكمية
                          4: const pw.FlexColumnWidth(1.5), // الشركة
                          5: const pw.FlexColumnWidth(2), // الدواء
                          6: const pw.FixedColumnWidth(35), // الرقم
                        }
                      : {
                          // Reversed for RTL visual reading: هدية, الكمية, الشركة, الدواء, الرقم
                          0: const pw.FlexColumnWidth(1), // هدية
                          1: const pw.FlexColumnWidth(1), // الكمية
                          2: const pw.FlexColumnWidth(1.5), // الشركة
                          3: const pw.FlexColumnWidth(2), // الدواء
                          4: const pw.FixedColumnWidth(35), // الرقم
                        },
                  children: [
                    // Header row (RTL order: الرقم, الدواء, الشركة, الكمية, السعر, المجموع)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: pricingEnabled
                          ? [
                              // Reversed order for RTL visual reading: المجموع, السعر, هدية, الكمية, الشركة, الدواء, الرقم
                              // (Visually: الرقم appears on RIGHT, المجموع appears on LEFT)
                              // المجموع - FIRST in array (leftmost visually in RTL)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'المجموع',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // السعر - SECOND in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'السعر',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // هدية - THIRD in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'هدية',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الكمية - FOURTH in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الكمية',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الشركة - FIFTH in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الشركة',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الدواء - SIXTH in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الدواء',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الرقم - LAST in array (rightmost visually in RTL)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الرقم',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ),
                            ]
                          : [
                              // Reversed order for RTL visual reading: هدية, الكمية, الشركة, الدواء, الرقم
                              // (Visually: الرقم appears on RIGHT, الكمية appears on LEFT)
                              // هدية - FIRST in array (leftmost visually in RTL)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'هدية',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الكمية - SECOND in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الكمية',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الشركة - THIRD in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الشركة',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الدواء - FOURTH in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الدواء',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الرقم - LAST in array (rightmost visually in RTL)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'الرقم',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                    ),
                    // Data rows (RTL order: الرقم, الدواء, الشركة, الكمية, السعر, المجموع)
                    ...chunkItems.asMap().entries.map((entry) {
                      final itemIndex = entry.key;
                      final item = entry.value;
                      final globalIndex =
                          startIndex + itemIndex + 1; // 1-based numbering
                      final priceUsd = (item['price_usd'] as num?)?.toDouble();
                      final priceSyp = (item['price_syp'] as num?)?.toDouble();
                      final fallbackPrice =
                          (item['price'] as num?)?.toDouble() ?? 0.0;
                      final displayPrice = currencyMode == 'syp'
                          ? ((priceSyp ?? 0) > 0
                              ? priceSyp!
                              : ((priceUsd ?? 0) > 0 ? priceUsd! : fallbackPrice))
                          : ((priceUsd ?? 0) > 0
                              ? priceUsd!
                              : ((priceSyp ?? 0) > 0 ? priceSyp! : fallbackPrice));
                      final qty = (item['qty'] as num?)?.toInt() ?? 0;
                      final giftQty = (item['gift_qty'] as num?)?.toInt() ?? 0;
                      final isGiftOnly = (item['is_gift'] as int? ?? 0) == 1;
                      final effectiveGiftQty =
                          giftQty > 0 ? giftQty : (isGiftOnly ? qty : 0);
                      final giftDisplayText =
                          effectiveGiftQty > 0 ? effectiveGiftQty.toString() : '';
                      final total = displayPrice * qty;

                      final medicineName = item['medicine_name'] ?? 'غير معروف';
                      final companyName = item['company_name'] ?? 'غير معروف';

                      return pw.TableRow(
                        children: pricingEnabled
                            ? [
                                // Reversed order for RTL visual reading: المجموع, السعر, هدية, الكمية, الشركة, الدواء, الرقم
                                // (Visually: الرقم appears on RIGHT, المجموع appears on LEFT)
                                // المجموع - FIRST in array (leftmost visually in RTL)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${total.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // السعر - SECOND in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${displayPrice.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(fontSize: 9),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // هدية - THIRD in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      giftDisplayText,
                                      style: getArabicStyle(fontSize: 9),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الكمية - FOURTH in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      qty.toString(),
                                      style: getArabicStyle(fontSize: 9),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الشركة - FIFTH in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      companyName,
                                      style: getArabicStyle(fontSize: 9),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                 // الدواء - SIXTH in array
                                 pw.Padding(
                                   padding: const pw.EdgeInsets.all(4),
                                   child: pw.Directionality(
                                     textDirection: pw.TextDirection.rtl,
                                     child: pw.Text(
                                       medicineName,
                                       style: getArabicStyle(
                                         fontSize: 9,
                                         fontWeight: pw.FontWeight.bold,
                                       ),
                                       textDirection: pw.TextDirection.rtl,
                                     ),
                                   ),
                                 ),
                                 // الرقم - LAST in array (rightmost visually in RTL)
                                 pw.Padding(
                                   padding: const pw.EdgeInsets.all(4),
                                   child: pw.Directionality(
                                     textDirection: pw.TextDirection.rtl,
                                     child: pw.Text(
                                       globalIndex.toString(),
                                       style: getArabicStyle(fontSize: 9),
                                       textAlign: pw.TextAlign.center,
                                     ),
                                   ),
                                 ),
                               ]
                            : [
                                // Reversed order for RTL visual reading: هدية, الكمية, الشركة, الدواء, الرقم
                                // (Visually: الرقم appears on RIGHT, الكمية appears on LEFT)
                                // هدية - FIRST in array (leftmost visually in RTL)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      giftDisplayText,
                                      style: getArabicStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الكمية - SECOND in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      qty.toString(),
                                      style: getArabicStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الشركة - THIRD in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      companyName,
                                      style: getArabicStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                 // الدواء - FOURTH in array
                                 pw.Padding(
                                   padding: const pw.EdgeInsets.all(6),
                                   child: pw.Directionality(
                                     textDirection: pw.TextDirection.rtl,
                                     child: pw.Text(
                                       medicineName,
                                       style: getArabicStyle(
                                         fontSize: 10,
                                         fontWeight: pw.FontWeight.bold,
                                       ),
                                       textDirection: pw.TextDirection.rtl,
                                     ),
                                   ),
                                 ),
                                 // الرقم - LAST in array (rightmost visually in RTL)
                                 pw.Padding(
                                   padding: const pw.EdgeInsets.all(6),
                                   child: pw.Directionality(
                                     textDirection: pw.TextDirection.rtl,
                                     child: pw.Text(
                                       globalIndex.toString(),
                                       style: getArabicStyle(fontSize: 10),
                                       textAlign: pw.TextAlign.center,
                                     ),
                                   ),
                                 ),
                               ],
                      );
                    }),
                  ],
                ),
        ],
      ),
    );
  }

  // Build gifts section (shown on last page if gifts exist)
  pw.Widget buildGiftsSection() {
    if (giftOrderItems.isEmpty) return pw.SizedBox.shrink();
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 10),
          pw.Text(
            'الهدايا',
            style: getArabicStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.teal200),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),   // الكمية
              1: const pw.FlexColumnWidth(3),   // اسم الهدية
              2: const pw.FixedColumnWidth(35), // الرقم
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Text('الكمية', style: getArabicStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Text('اسم الهدية', style: getArabicStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Text('الرقم', style: getArabicStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                  ),
                ],
              ),
              ...giftOrderItems.asMap().entries.map((entry) {
                final i = entry.key;
                final g = entry.value;
                final name = (g['gift_name'] as String?) ?? 'غير معروف';
                final qty = (g['qty'] as num?)?.toInt() ?? 0;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(qty.toString(), style: getArabicStyle(fontSize: 9)),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(name, style: getArabicStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text((i + 1).toString(), style: getArabicStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Build footer summary (shown only on last page)
  pw.Widget buildFooter() {
    // Definitions:
    // - Items count = number of distinct order lines (rows in the table)
    // - Quantity count = sum of quantities across all lines (includes gift_qty)
    final itemsCount = items.length;
    int qtyCount = 0;
    for (final item in items) {
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final giftQty = (item['gift_qty'] as num?)?.toInt() ?? 0;
      qtyCount += qty + giftQty;
    }

    if (itemsCount == 0) return pw.SizedBox.shrink();

    final totalText =
        _calculateTotal(items, currencyMode, currencySymbol);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          border: pw.Border.all(color: PdfColors.blue),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'عدد الأصناف:',
                  style: getArabicStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  itemsCount.toString(),
                  style: getArabicStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'مجموع الأدوية:',
                  style: getArabicStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  qtyCount.toString(),
                  style: getArabicStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
            if (pricingEnabled) ...[
              pw.Divider(color: PdfColors.blue),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'المجموع النهائي:',
                    style: getArabicStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    totalText,
                    style: getArabicStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Add pages for each chunk of items
  for (int pageIndex = 0; pageIndex < itemChunks.length; pageIndex++) {
    final isFirstPage = pageIndex == 0;
    final isLastPage = pageIndex == itemChunks.length - 1;
    final chunkItems = itemChunks[pageIndex];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header (only on first page)
                if (isFirstPage) buildHeader(),

                // Items table for this page (with starting index for numbering)
                buildItemsTable(chunkItems, pageIndex * itemsPerPage),

                // Footer with totals (only on last page)
                if (isLastPage) buildGiftsSection(),
                if (isLastPage) buildFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  return pdf.save();
}

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return dateString;
  }
}

String _calculateTotal(
  List<Map<String, dynamic>> items,
  String currencyMode,
  String currencySymbol,
) {
  double total = 0.0;
  for (final item in items) {
    // Gift-only rows do not affect total price (gift_qty also does not affect totals)
    final isGiftOnly = (item['is_gift'] as int? ?? 0) == 1;
    if (isGiftOnly) continue;

    final priceUsd = (item['price_usd'] as num?)?.toDouble();
    final priceSyp = (item['price_syp'] as num?)?.toDouble();
    final fallbackPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final unitPrice = currencyMode == 'syp'
        ? ((priceSyp ?? 0) > 0
            ? priceSyp!
            : ((priceUsd ?? 0) > 0 ? priceUsd! : fallbackPrice))
        : ((priceUsd ?? 0) > 0
            ? priceUsd!
            : ((priceSyp ?? 0) > 0 ? priceSyp! : fallbackPrice));
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    total += unitPrice * qty;
  }

  return '${total.toStringAsFixed(2)} $currencySymbol';
}

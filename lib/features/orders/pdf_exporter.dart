import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/db/database_helper.dart';

Future<Uint8List> generateOrderPdf(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> items,
  Map<String, dynamic> pharmacy,
) async {
  // If items list is empty, try to fetch from database
  // This handles cases where order object doesn't have items loaded
  if (items.isEmpty && order['id'] != null) {
    try {
      final dbHelper = DatabaseHelper.instance;
      final orderId = order['id'] as int;
      items = await dbHelper.fetchOrderItemsWithDetails(orderId);
    } catch (e) {
      // If DB fetch fails, continue with empty items list
      print('Warning: Could not fetch items from DB: $e');
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
    print('Warning: Arabic font not found. Using default font. Error: $e');
    print('Please ensure Cairo-Regular.ttf is placed in assets/fonts/');
  }

  // Create text style with Arabic font
  pw.TextStyle getArabicStyle({
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
  }) {
    return pw.TextStyle(
      font: arabicFont, // Will be null if font not loaded, using default
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  // Get agent data from SharedPreferences
  final activationService = ActivationService();
  final agentName = await activationService.getAgentName();
  final agentPhone = await activationService.getAgentPhone();

  // Get pricing settings
  final settingsService = SettingsService();
  final pricingEnabled = await settingsService.isPricingEnabled();
  final currencyMode = await settingsService.getCurrencyMode();
  final exchangeRate = await settingsService.getExchangeRate();
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
                  fontSize: 20,
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
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (agentName.isNotEmpty)
                          pw.Text(
                            'اسم المندوب: $agentName',
                            style: getArabicStyle(fontSize: 9),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        if (agentName.isNotEmpty && agentPhone.isNotEmpty)
                          pw.SizedBox(height: 2),
                        if (agentPhone.isNotEmpty)
                          pw.Text(
                            'رقم المندوب: $agentPhone',
                            style: getArabicStyle(fontSize: 9),
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
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'الاسم: ${pharmacy['pharmacy_name'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 9),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'العنوان: ${pharmacy['pharmacy_address'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 9),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'الهاتف: ${pharmacy['pharmacy_phone'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 9),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'التاريخ: ${_formatDate(order['created_at'] as String)}',
                        style: getArabicStyle(fontSize: 9),
                        textDirection: pw.TextDirection.rtl,
                      ),
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
              fontSize: 14,
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
                      style: getArabicStyle(fontSize: 11),
                    ),
                  ),
                )
              : pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: pricingEnabled
                      ? {
                          // Reversed for RTL: المجموع, السعر, الكمية, هدية, الشركة, الدواء, الرقم
                          0: const pw.FlexColumnWidth(1.5), // المجموع
                          1: const pw.FlexColumnWidth(1.5), // السعر
                          2: const pw.FlexColumnWidth(1), // الكمية
                          3: const pw.FlexColumnWidth(1), // هدية
                          4: const pw.FlexColumnWidth(1.5), // الشركة
                          5: const pw.FlexColumnWidth(2), // الدواء
                          6: const pw.FixedColumnWidth(35), // الرقم
                        }
                      : {
                          // Reversed for RTL: الكمية, هدية, الشركة, الدواء, الرقم
                          0: const pw.FlexColumnWidth(1), // الكمية
                          1: const pw.FlexColumnWidth(1), // هدية
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
                              // Reversed order for RTL: المجموع, السعر, الكمية, هدية, الشركة, الدواء, الرقم
                              // (Visually: الرقم appears on RIGHT, المجموع appears on LEFT)
                              // المجموع - FIRST in array (leftmost visually in RTL)
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'المجموع',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // السعر - SECOND in array
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'السعر',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                              ),
                              // الكمية - THIRD in array
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
                              // هدية - FOURTH in array
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
                              // الشركة - FIFTH in array
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
                              // الدواء - SIXTH in array
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
                            ]
                          : [
                              // Reversed order for RTL: الكمية, هدية, الشركة, الدواء, الرقم
                              // (Visually: الرقم appears on RIGHT, الكمية appears on LEFT)
                              // الكمية - FIRST in array (leftmost visually in RTL)
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
                              // هدية - SECOND in array
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
                      // Use price_usd from medicine record (fallback to order_items.price for backward compatibility)
                      final priceUsd =
                          (item['price_usd'] as num?)?.toDouble() ??
                              (item['price'] as num?)?.toDouble() ??
                              0.0;
                      double displayPrice = priceUsd;
                      if (pricingEnabled && currencyMode == 'syp') {
                        displayPrice = priceUsd * exchangeRate;
                      }
                      final qty = (item['qty'] as num?)?.toInt() ?? 0;
                      final giftQty = (item['gift_qty'] as num?)?.toInt() ?? 0;
                      final isGiftOnly = (item['is_gift'] as int? ?? 0) == 1;
                      final total = displayPrice * qty;

                      final medicineName = item['medicine_name'] ?? 'غير معروف';
                      final companyName = item['company_name'] ?? 'غير معروف';
                      final source = item['medicine_source'] as String?;
                      final form = item['medicine_form'] as String?;
                      final notes = item['medicine_notes'] as String?;

                      // Build description string with optional fields (source, form, notes, gift)
                      final List<String> descriptionParts = [];
                      if (source != null && source.isNotEmpty) {
                        descriptionParts.add('المصدر: $source');
                      }
                      if (form != null && form.isNotEmpty) {
                        descriptionParts.add('النوع: $form');
                      }
                      if (notes != null && notes.isNotEmpty) {
                        descriptionParts.add('ملاحظات: $notes');
                      }
                      if (isGiftOnly || giftQty > 0) {
                        descriptionParts
                            .add(giftQty > 0 ? 'هدية: $giftQty' : 'هدية');
                      }
                      final description = descriptionParts.isNotEmpty
                          ? '(${descriptionParts.join(' — ')})'
                          : '';

                      return pw.TableRow(
                        children: pricingEnabled
                            ? [
                                // Reversed order for RTL: المجموع, السعر, الكمية, هدية, الشركة, الدواء, الرقم
                                // (Visually: الرقم appears on RIGHT, المجموع appears on LEFT)
                                // المجموع - FIRST in array (leftmost visually in RTL)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${total.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // السعر - SECOND in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${displayPrice.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الكمية - THIRD in array
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
                                // هدية - FOURTH in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      (isGiftOnly ? qty : giftQty).toString(),
                                      style: getArabicStyle(fontSize: 10),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ),
                                ),
                                // الشركة - FIFTH in array
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
                                // الدواء - SIXTH in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          medicineName,
                                          style: getArabicStyle(
                                            fontSize: 10,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                          textDirection: pw.TextDirection.rtl,
                                        ),
                                        if (description.isNotEmpty) ...[
                                          pw.SizedBox(height: 2),
                                          pw.Directionality(
                                            textDirection: pw.TextDirection.rtl,
                                            child: pw.Text(
                                              description,
                                              style: getArabicStyle(
                                                fontSize: 8,
                                              ),
                                              textDirection:
                                                  pw.TextDirection.rtl,
                                            ),
                                          ),
                                        ],
                                      ],
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
                              ]
                            : [
                                // Reversed order for RTL: الكمية, هدية, الشركة, الدواء, الرقم
                                // (Visually: الرقم appears on RIGHT, الكمية appears on LEFT)
                                // الكمية - FIRST in array (leftmost visually in RTL)
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
                                // هدية - SECOND in array
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      (isGiftOnly ? qty : giftQty).toString(),
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
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          medicineName,
                                          style: getArabicStyle(
                                            fontSize: 10,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                          textDirection: pw.TextDirection.rtl,
                                        ),
                                        if (description.isNotEmpty) ...[
                                          pw.SizedBox(height: 2),
                                          pw.Directionality(
                                            textDirection: pw.TextDirection.rtl,
                                            child: pw.Text(
                                              description,
                                              style: getArabicStyle(
                                                fontSize: 8,
                                              ),
                                              textDirection:
                                                  pw.TextDirection.rtl,
                                            ),
                                          ),
                                        ],
                                      ],
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
        _calculateTotal(items, currencyMode, exchangeRate, currencySymbol);

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
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  itemsCount.toString(),
                  style: getArabicStyle(
                    fontSize: 12,
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
                  'مجموع الأقلام:',
                  style: getArabicStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  qtyCount.toString(),
                  style: getArabicStyle(
                    fontSize: 12,
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
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    totalText,
                    style: getArabicStyle(
                      fontSize: 16,
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
  double exchangeRate,
  String currencySymbol,
) {
  double totalUsd = 0.0;
  for (final item in items) {
    // Gift-only rows do not affect total price (gift_qty also does not affect totals)
    final isGiftOnly = (item['is_gift'] as int? ?? 0) == 1;
    if (isGiftOnly) continue;

    // Use price_usd from medicine record (fallback to order_items.price for backward compatibility)
    final priceUsd = (item['price_usd'] as num?)?.toDouble() ??
        (item['price'] as num?)?.toDouble() ??
        0.0;
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    totalUsd += priceUsd * qty;
  }

  double displayTotal = totalUsd;
  if (currencyMode == 'syp') {
    displayTotal = totalUsd * exchangeRate;
  }

  return '${displayTotal.toStringAsFixed(2)} $currencySymbol';
}

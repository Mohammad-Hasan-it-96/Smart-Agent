import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';

Future<Uint8List> generateOrderPdf(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> items,
  Map<String, dynamic> pharmacy,
) async {
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

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  pricingEnabled
                      ? 'المندوب الذكي - فاتورة مبيع'
                      : 'المندوب الذكي - طلبية',
                  style: getArabicStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Agent Info (if available)
              if (agentName.isNotEmpty || agentPhone.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
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
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        if (agentName.isNotEmpty)
                          pw.Text(
                            'اسم المندوب: $agentName',
                            style: getArabicStyle(fontSize: 12),
                          ),
                        if (agentName.isNotEmpty && agentPhone.isNotEmpty)
                          pw.SizedBox(height: 4),
                        if (agentPhone.isNotEmpty)
                          pw.Text(
                            'رقم المندوب: $agentPhone',
                            style: getArabicStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Pharmacy Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
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
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'الاسم: ${pharmacy['pharmacy_name'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'العنوان: ${pharmacy['pharmacy_address'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'الهاتف: ${pharmacy['pharmacy_phone'] ?? 'غير معروف'}',
                        style: getArabicStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'التاريخ: ${_formatDate(order['created_at'] as String)}',
                        style: getArabicStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Items Table
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'عناصر الطلبية',
                      style: getArabicStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey),
                      columnWidths: pricingEnabled
                          ? {
                              0: const pw.FlexColumnWidth(2),
                              1: const pw.FlexColumnWidth(2),
                              2: const pw.FlexColumnWidth(1),
                              3: const pw.FlexColumnWidth(1.5),
                              4: const pw.FlexColumnWidth(1.5),
                            }
                          : {
                              0: const pw.FlexColumnWidth(2),
                              1: const pw.FlexColumnWidth(2),
                              2: const pw.FlexColumnWidth(1),
                            },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Directionality(
                                textDirection: pw.TextDirection.rtl,
                                child: pw.Text(
                                  'الدواء',
                                  style: getArabicStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Directionality(
                                textDirection: pw.TextDirection.rtl,
                                child: pw.Text(
                                  'الكمية',
                                  style: getArabicStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (pricingEnabled) ...[
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'السعر',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    'المجموع',
                                    style: getArabicStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Data rows
                        ...items.map((item) {
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
                          final total = displayPrice * qty;

                          final medicineName =
                              item['medicine_name'] ?? 'غير معروف';
                          final companyName =
                              item['company_name'] ?? 'غير معروف';
                          final source = item['medicine_source'] as String?;
                          final form = item['medicine_form'] as String?;
                          final notes = item['medicine_notes'] as String?;

                          // Build description string with optional fields
                          final List<String> descriptionParts = [companyName];
                          if (source != null && source.isNotEmpty) {
                            descriptionParts.add('المصدر: $source');
                          }
                          if (form != null && form.isNotEmpty) {
                            descriptionParts.add('النوع: $form');
                          }
                          if (notes != null && notes.isNotEmpty) {
                            descriptionParts.add('ملاحظات: $notes');
                          }
                          final description = descriptionParts.join(' — ');

                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        medicineName,
                                        style: getArabicStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        '($description)',
                                        style: getArabicStyle(
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    qty.toString(),
                                    style: getArabicStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              if (pricingEnabled) ...[
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${displayPrice.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Text(
                                      '${total.toStringAsFixed(2)} $currencySymbol',
                                      style: getArabicStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ],
                    ),
                    // Total (if pricing enabled)
                    if (pricingEnabled) ...[
                      pw.SizedBox(height: 16),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          border: pw.Border.all(color: PdfColors.blue),
                        ),
                        child: pw.Directionality(
                          textDirection: pw.TextDirection.rtl,
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                _calculateTotal(items, currencyMode,
                                    exchangeRate, currencySymbol),
                                style: getArabicStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'المجموع النهائي:',
                                style: getArabicStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

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

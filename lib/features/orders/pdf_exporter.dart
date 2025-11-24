import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/services/activation_service.dart';

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
                  'المندوب الذكي - طلبية',
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
                      columnWidths: {
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
                                  'الشركة',
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
                          ],
                        ),
                        // Data rows
                        ...items.map((item) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    item['medicine_name'] ?? 'غير معروف',
                                    style: getArabicStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    item['company_name'] ?? 'غير معروف',
                                    style: getArabicStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Directionality(
                                  textDirection: pw.TextDirection.rtl,
                                  child: pw.Text(
                                    item['qty'].toString(),
                                    style: getArabicStyle(fontSize: 11),
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

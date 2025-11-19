import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> generateOrderPdf(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> items,
  Map<String, dynamic> pharmacy,
) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title
            pw.Center(
              child: pw.Text(
                'المندوب الذكي - طلبية',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Pharmacy Info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'معلومات الصيدلية',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'الاسم: ${pharmacy['pharmacy_name'] ?? 'غير معروف'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'العنوان: ${pharmacy['pharmacy_address'] ?? 'غير معروف'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'الهاتف: ${pharmacy['pharmacy_phone'] ?? 'غير معروف'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'التاريخ: ${_formatDate(order['created_at'] as String)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items Table
            pw.Text(
              'عناصر الطلبية',
              style: pw.TextStyle(
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
                      child: pw.Text(
                        'الدواء',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'الشركة',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'الكمية',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
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
                        child: pw.Text(
                          item['medicine_name'] ?? 'غير معروف',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item['company_name'] ?? 'غير معروف',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item['qty'].toString(),
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
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

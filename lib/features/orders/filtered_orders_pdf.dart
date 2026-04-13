import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/db/database_helper.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import 'order_filter.dart';

// ── Private data models ───────────────────────────────────────────────────────

class _PharmacySummary {
  final String name;
  final int orderCount;
  final int totalQty;
  final double totalUsd;
  final double totalSyp;
  const _PharmacySummary({
    required this.name,
    required this.orderCount,
    required this.totalQty,
    required this.totalUsd,
    required this.totalSyp,
  });
}

class _CompanySummary {
  final String name;
  final int orderCount;
  final int totalQty;
  final double totalUsd;
  final double totalSyp;
  const _CompanySummary({
    required this.name,
    required this.orderCount,
    required this.totalQty,
    required this.totalUsd,
    required this.totalSyp,
  });
}

class _ReportData {
  final int totalOrders;
  final int totalQty;
  final double totalUsd;
  final double totalSyp;
  final List<_PharmacySummary> pharmacies;
  final List<_CompanySummary> companies;
  const _ReportData({
    required this.totalOrders,
    required this.totalQty,
    required this.totalUsd,
    required this.totalSyp,
    required this.pharmacies,
    required this.companies,
  });
}

// ── Data gathering ────────────────────────────────────────────────────────────

Future<_ReportData> _gatherData(
    DatabaseHelper dbHelper, OrderFilter filter) async {
  final db = await dbHelper.database;
  final (:where, :args) = filter.buildGroupedWhere();

  // Grand totals
  final totalRows = await db.rawQuery('''
    SELECT
      COUNT(DISTINCT orders.id)                                                AS total_orders,
      COALESCE(SUM(COALESCE(oi.qty,0) + COALESCE(oi.gift_qty,0)), 0)         AS total_qty,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_usd, oi.price, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                    AS total_usd,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_syp, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                    AS total_syp
    FROM orders
    LEFT JOIN order_items oi ON oi.order_id = orders.id
    LEFT JOIN medicines   m  ON oi.medicine_id = m.id
    $where
  ''', args);

  final row0 = totalRows.first;
  final totalOrders = (row0['total_orders'] as num?)?.toInt() ?? 0;
  final totalQty    = (row0['total_qty']    as num?)?.toInt() ?? 0;
  final totalUsd    = (row0['total_usd']    as num?)?.toDouble() ?? 0.0;
  final totalSyp    = (row0['total_syp']    as num?)?.toDouble() ?? 0.0;

  // Per-pharmacy breakdown
  final pharmRows = await db.rawQuery('''
    SELECT
      COALESCE(p.name, 'غير معروف')                                          AS ph_name,
      COUNT(DISTINCT orders.id)                                               AS order_count,
      COALESCE(SUM(COALESCE(oi.qty,0) + COALESCE(oi.gift_qty,0)), 0)        AS total_qty,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_usd, oi.price, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                   AS total_usd,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_syp, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                   AS total_syp
    FROM orders
    LEFT JOIN pharmacies  p  ON orders.pharmacy_id = p.id
    LEFT JOIN order_items oi ON oi.order_id = orders.id
    LEFT JOIN medicines   m  ON oi.medicine_id = m.id
    $where
    GROUP BY orders.pharmacy_id, COALESCE(p.name, 'غير معروف')
    ORDER BY ph_name ASC
  ''', args);

  final pharmacies = pharmRows
      .map((r) => _PharmacySummary(
            name:       r['ph_name']     as String,
            orderCount: (r['order_count'] as num?)?.toInt()    ?? 0,
            totalQty:   (r['total_qty']   as num?)?.toInt()    ?? 0,
            totalUsd:   (r['total_usd']   as num?)?.toDouble() ?? 0.0,
            totalSyp:   (r['total_syp']   as num?)?.toDouble() ?? 0.0,
          ))
      .toList();

  // Per-company breakdown
  final compRows = await db.rawQuery('''
    SELECT
      COALESCE(c.name, 'غير معروف')                                          AS co_name,
      COUNT(DISTINCT orders.id)                                               AS order_count,
      COALESCE(SUM(COALESCE(oi.qty,0) + COALESCE(oi.gift_qty,0)), 0)        AS total_qty,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_usd, oi.price, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                   AS total_usd,
      COALESCE(SUM(CASE WHEN oi.is_gift = 1 THEN 0
                   ELSE COALESCE(m.price_syp, 0) * COALESCE(oi.qty,0)
                   END), 0)                                                   AS total_syp
    FROM orders
    LEFT JOIN order_items oi ON oi.order_id = orders.id
    LEFT JOIN medicines   m  ON oi.medicine_id = m.id
    LEFT JOIN companies   c  ON m.company_id = c.id
    $where
    GROUP BY c.id, COALESCE(c.name, 'غير معروف')
    ORDER BY co_name ASC
  ''', args);

  final companies = compRows
      .map((r) => _CompanySummary(
            name:       r['co_name']     as String,
            orderCount: (r['order_count'] as num?)?.toInt()    ?? 0,
            totalQty:   (r['total_qty']   as num?)?.toInt()    ?? 0,
            totalUsd:   (r['total_usd']   as num?)?.toDouble() ?? 0.0,
            totalSyp:   (r['total_syp']   as num?)?.toDouble() ?? 0.0,
          ))
      .toList();

  return _ReportData(
    totalOrders: totalOrders,
    totalQty:    totalQty,
    totalUsd:    totalUsd,
    totalSyp:    totalSyp,
    pharmacies:  pharmacies,
    companies:   companies,
  );
}

// ── Filter description lines ──────────────────────────────────────────────────

List<String> _filterLines(OrderFilter filter) {
  if (!filter.isActive) return ['جميع الطلبيات (بدون تصفية)'];

  final lines = <String>[];

  if (filter.month != null) {
    lines.add('الشهر: ${OrderFilter.monthLabel(filter.month!)}');
  } else {
    if (filter.fromDate != null) {
      final p = filter.fromDate!.split('-');
      lines.add('من: ${p[2]}/${p[1]}/${p[0]}');
    }
    if (filter.toDate != null) {
      final p = filter.toDate!.split('-');
      lines.add('إلى: ${p[2]}/${p[1]}/${p[0]}');
    }
    if (filter.fromDate == null && filter.toDate == null) {
      lines.add('جميع التواريخ');
    }
  }

  if (filter.pharmacies.isNotEmpty) {
    final names = filter.pharmacies.map((p) => p.name).toList();
    lines.add(names.length <= 3
        ? 'الصيدليات: ${names.join('، ')}'
        : 'الصيدليات: ${names.take(3).join('، ')} و${names.length - 3} أخرى');
  } else {
    lines.add('جميع الصيدليات');
  }

  if (filter.companies.isNotEmpty) {
    final names = filter.companies.map((c) => c.name).toList();
    lines.add(names.length <= 3
        ? 'الشركات: ${names.join('، ')}'
        : 'الشركات: ${names.take(3).join('، ')} و${names.length - 3} أخرى');
  } else {
    lines.add('جميع الشركات');
  }

  return lines;
}

// ── Main PDF generator ────────────────────────────────────────────────────────

/// Generates a filtered-orders summary PDF report and returns the raw bytes.
/// Share via [Printing.sharePdf].
Future<Uint8List> generateFilteredOrdersReport({
  required OrderFilter filter,
  required DatabaseHelper dbHelper,
}) async {
  // ── Load font ──────────────────────────────────────────────────────────────
  pw.Font? arabicFont;
  try {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    arabicFont = pw.Font.ttf(fontData);
  } catch (e) {
    debugPrint('Warning: Arabic font not found. Error: $e');
  }

  pw.TextStyle style({
    double fontSize = 10,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
  }) =>
      pw.TextStyle(font: arabicFont, fontSize: fontSize, fontWeight: fontWeight, color: color);

  pw.Widget rtl(pw.Widget child) =>
      pw.Directionality(textDirection: pw.TextDirection.rtl, child: child);

  pw.Widget cell(String text,
      {double fontSize = 9,
      pw.FontWeight fw = pw.FontWeight.normal,
      pw.TextAlign align = pw.TextAlign.right}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: rtl(pw.Text(text, style: style(fontSize: fontSize, fontWeight: fw),
            textAlign: align, textDirection: pw.TextDirection.rtl)),
      );

  // ── Agent + settings ───────────────────────────────────────────────────────
  final agentName  = await getIt<ActivationService>().getAgentName();
  final agentPhone = await getIt<ActivationService>().getAgentPhone();
  final settingsSvc   = getIt<SettingsService>();
  final pricingEnabled = await settingsSvc.isPricingEnabled();
  final currencyMode   = await settingsSvc.getCurrencyMode();
  final currencySymbol = currencyMode == 'syp' ? 'ل.س' : '\$';

  // ── Gather data ────────────────────────────────────────────────────────────
  final data = await _gatherData(dbHelper, filter);

  // ── Helpers ────────────────────────────────────────────────────────────────
  String fmtAmt(double v) => '${v.toStringAsFixed(2)} $currencySymbol';
  double displayAmt(_PharmacySummary p) =>
      currencyMode == 'syp' ? p.totalSyp : p.totalUsd;
  double displayAmtC(_CompanySummary c) =>
      currencyMode == 'syp' ? c.totalSyp : c.totalUsd;

  final now    = DateTime.now();
  final nowStr = '${now.year}/${now.month.toString().padLeft(2,'0')}/${now.day.toString().padLeft(2,'0')}  '
                 '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

  final descLines = _filterLines(filter);

  // ── Header row decoration ──────────────────────────────────────────────────
  const headerDeco = pw.BoxDecoration(color: PdfColors.blueGrey800);

  pw.Widget headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: rtl(pw.Text(text,
            style: style(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            textAlign: pw.TextAlign.right,
            textDirection: pw.TextDirection.rtl)),
      );

  // ── Pharmacy table ─────────────────────────────────────────────────────────
  pw.Widget buildPharmacyTable() {
    final colWidths = pricingEnabled
        ? {
            0: const pw.FlexColumnWidth(2.5), // الصيدلية
            1: const pw.FlexColumnWidth(1),   // عدد الطلبيات
            2: const pw.FlexColumnWidth(1),   // الكميات
            3: const pw.FlexColumnWidth(1.5), // المبلغ
          }
        : {
            0: const pw.FlexColumnWidth(3),   // الصيدلية
            1: const pw.FlexColumnWidth(1.2), // عدد الطلبيات
            2: const pw.FlexColumnWidth(1.2), // الكميات
          };

    final headerRow = pw.TableRow(
      decoration: headerDeco,
      children: [
        if (pricingEnabled) headerCell('المبلغ'),
        headerCell('الكميات'),
        headerCell('عدد الطلبيات'),
        headerCell('الصيدلية'),
      ],
    );

    final dataRows = data.pharmacies.map((p) {
      return pw.TableRow(children: [
        if (pricingEnabled) cell(fmtAmt(displayAmt(p))),
        cell(p.totalQty.toString()),
        cell(p.orderCount.toString()),
        cell(p.name),
      ]);
    }).toList();

    // Totals row
    final totalPharmUsd = data.pharmacies.fold(0.0, (s, p) => s + p.totalUsd);
    final totalPharmSyp = data.pharmacies.fold(0.0, (s, p) => s + p.totalSyp);
    final totalPharmQty = data.pharmacies.fold(0, (s, p) => s + p.totalQty);
    final totalPharmOrders = data.pharmacies.fold(0, (s, p) => s + p.orderCount);
    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
      children: [
        if (pricingEnabled)
          cell(fmtAmt(currencyMode == 'syp' ? totalPharmSyp : totalPharmUsd),
              fw: pw.FontWeight.bold),
        cell(totalPharmQty.toString(), fw: pw.FontWeight.bold),
        cell(totalPharmOrders.toString(), fw: pw.FontWeight.bold),
        cell('الإجمالي', fw: pw.FontWeight.bold),
      ],
    );

    return rtl(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: colWidths,
      children: [headerRow, ...dataRows, totalRow],
    ));
  }

  // ── Company table ──────────────────────────────────────────────────────────
  pw.Widget buildCompanyTable() {
    final colWidths = pricingEnabled
        ? {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
          }
        : {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.2),
          };

    final headerRow = pw.TableRow(
      decoration: headerDeco,
      children: [
        if (pricingEnabled) headerCell('المبلغ'),
        headerCell('الكميات'),
        headerCell('عدد الطلبيات'),
        headerCell('الشركة'),
      ],
    );

    final dataRows = data.companies.map((c) {
      return pw.TableRow(children: [
        if (pricingEnabled) cell(fmtAmt(displayAmtC(c))),
        cell(c.totalQty.toString()),
        cell(c.orderCount.toString()),
        cell(c.name),
      ]);
    }).toList();

    final totalCoUsd = data.companies.fold(0.0, (s, c) => s + c.totalUsd);
    final totalCoSyp = data.companies.fold(0.0, (s, c) => s + c.totalSyp);
    final totalCoQty = data.companies.fold(0, (s, c) => s + c.totalQty);
    final totalCoOrders = data.companies.fold(0, (s, c) => s + c.orderCount);
    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blue50),
      children: [
        if (pricingEnabled)
          cell(fmtAmt(currencyMode == 'syp' ? totalCoSyp : totalCoUsd),
              fw: pw.FontWeight.bold),
        cell(totalCoQty.toString(), fw: pw.FontWeight.bold),
        cell(totalCoOrders.toString(), fw: pw.FontWeight.bold),
        cell('الإجمالي', fw: pw.FontWeight.bold),
      ],
    );

    return rtl(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: colWidths,
      children: [headerRow, ...dataRows, totalRow],
    ));
  }

  // ── Assemble PDF (MultiPage handles auto-pagination) ──────────────────────
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      build: (context) => [
        // ── 1. Title ────────────────────────────────────────────────────────
        rtl(pw.Center(
          child: pw.Text(
            'المندوب الذكي — تقرير الطلبيات',
            style: style(fontSize: 18, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl,
          ),
        )),
        pw.SizedBox(height: 4),
        rtl(pw.Center(
          child: pw.Text(
            'تاريخ التصدير: $nowStr',
            style: style(fontSize: 9, color: PdfColors.grey600),
            textDirection: pw.TextDirection.rtl,
          ),
        )),
        pw.SizedBox(height: 14),

        // ── 2. Agent box + Filter summary box ───────────────────────────────
        rtl(pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Agent info
            pw.Container(
              width: 140,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: rtl(pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('معلومات المندوب',
                      style: style(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      textDirection: pw.TextDirection.rtl),
                  pw.SizedBox(height: 4),
                  if (agentName.isNotEmpty)
                    pw.Text('الاسم: $agentName',
                        style: style(fontSize: 8.5),
                        textDirection: pw.TextDirection.rtl),
                  if (agentPhone.isNotEmpty)
                    pw.Text('الهاتف: $agentPhone',
                        style: style(fontSize: 8.5),
                        textDirection: pw.TextDirection.rtl),
                ],
              )),
            ),
            pw.SizedBox(width: 12),
            // Filter summary
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: rtl(pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('نطاق التقرير',
                        style: style(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textDirection: pw.TextDirection.rtl),
                    pw.SizedBox(height: 4),
                    ...descLines.map((line) => pw.Text(line,
                        style: style(fontSize: 8.5),
                        textDirection: pw.TextDirection.rtl)),
                  ],
                )),
              ),
            ),
          ],
        )),
        pw.SizedBox(height: 16),

        // ── 3. Key statistics ────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        rtl(pw.Text('ملخص إجمالي',
            style: style(fontSize: 13, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl)),
        pw.SizedBox(height: 8),
        rtl(pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: rtl(pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox('عدد الطلبيات', data.totalOrders.toString(), arabicFont),
              _statBox('مجموع الوحدات', data.totalQty.toString(), arabicFont),
              if (pricingEnabled)
                _statBox(
                  'المبلغ الإجمالي',
                  fmtAmt(currencyMode == 'syp' ? data.totalSyp : data.totalUsd),
                  arabicFont,
                ),
            ],
          )),
        )),
        pw.SizedBox(height: 20),

        // ── 4. Per-pharmacy table ────────────────────────────────────────────
        if (data.pharmacies.isNotEmpty) ...[
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          rtl(pw.Text('تفصيل حسب الصيدلية',
              style: style(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl)),
          pw.SizedBox(height: 8),
          buildPharmacyTable(),
          pw.SizedBox(height: 20),
        ],

        // ── 5. Per-company table ─────────────────────────────────────────────
        if (data.companies.isNotEmpty) ...[
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          rtl(pw.Text('تفصيل حسب الشركة',
              style: style(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textDirection: pw.TextDirection.rtl)),
          pw.SizedBox(height: 8),
          buildCompanyTable(),
        ],

        // ── Empty-data notice ────────────────────────────────────────────────
        if (data.totalOrders == 0)
          rtl(pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 32),
              child: pw.Text('لا توجد طلبيات تطابق التصفية المحددة',
                  style: style(fontSize: 12, color: PdfColors.grey600),
                  textDirection: pw.TextDirection.rtl),
            ),
          )),
      ],
    ),
  );

  return pdf.save();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

pw.Widget _statBox(String label, String value, pw.Font? font) {
  pw.TextStyle s({double fs = 10, pw.FontWeight fw = pw.FontWeight.normal, PdfColor? c}) =>
      pw.TextStyle(font: font, fontSize: fs, fontWeight: fw, color: c);

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(value,
          style: s(fs: 16, fw: pw.FontWeight.bold, c: PdfColors.blue800),
          textDirection: pw.TextDirection.rtl),
      pw.SizedBox(height: 4),
      pw.Text(label,
          style: s(fs: 8, c: PdfColors.grey700),
          textDirection: pw.TextDirection.rtl),
    ],
  );
}


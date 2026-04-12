/// A selectable item (pharmacy or company) for multi-select filtering.
class FilterItem {
  final int id;
  final String name;

  const FilterItem(this.id, this.name);

  @override
  bool operator ==(Object other) => other is FilterItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Immutable order filter state, shared between [OrdersListScreen] and
/// [DailyOrdersScreen].
class OrderFilter {
  /// Start of date range 'YYYY-MM-DD', or null.
  final String? fromDate;

  /// End of date range 'YYYY-MM-DD', or null.
  final String? toDate;

  /// Quick month selector 'YYYY-MM', or null.
  /// Mutually exclusive with [fromDate]/[toDate] in the UI (selecting a month
  /// clears the custom range and vice-versa).
  final String? month;

  /// Selected pharmacies to include (empty = all pharmacies).
  final List<FilterItem> pharmacies;

  /// Selected companies to include (empty = all companies).
  final List<FilterItem> companies;

  const OrderFilter({
    this.fromDate,
    this.toDate,
    this.month,
    this.pharmacies = const [],
    this.companies = const [],
  });

  bool get isActive =>
      fromDate != null ||
      toDate != null ||
      month != null ||
      pharmacies.isNotEmpty ||
      companies.isNotEmpty;

  List<int> get pharmacyIds => pharmacies.map((e) => e.id).toList();
  List<int> get companyIds => companies.map((e) => e.id).toList();

  OrderFilter copyWith({
    bool clearFromDate = false,
    bool clearToDate = false,
    bool clearMonth = false,
    String? fromDate,
    String? toDate,
    String? month,
    List<FilterItem>? pharmacies,
    List<FilterItem>? companies,
  }) =>
      OrderFilter(
        fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
        toDate: clearToDate ? null : (toDate ?? this.toDate),
        month: clearMonth ? null : (month ?? this.month),
        pharmacies: pharmacies ?? this.pharmacies,
        companies: companies ?? this.companies,
      );

  // ── Query helpers ────────────────────────────────────────────────────

  /// Builds the full WHERE clause for the orders-grouped-by-day query.
  /// Returns an empty [where] string when no filters are active.
  ({String where, List<Object?> args}) buildGroupedWhere() {
    final clauses = <String>[];
    final args = <Object?>[];

    // Date range or month (month wins if both set)
    if (month != null) {
      clauses.add("SUBSTR(orders.created_at, 1, 7) = ?");
      args.add(month);
    } else {
      if (fromDate != null) {
        clauses.add("SUBSTR(orders.created_at, 1, 10) >= ?");
        args.add(fromDate);
      }
      if (toDate != null) {
        clauses.add("SUBSTR(orders.created_at, 1, 10) <= ?");
        args.add(toDate);
      }
    }

    // Pharmacy filter
    if (pharmacyIds.isNotEmpty) {
      final ph = List.filled(pharmacyIds.length, '?').join(',');
      clauses.add("orders.pharmacy_id IN ($ph)");
      args.addAll(pharmacyIds);
    }

    // Company filter via subquery on order_items ⟶ medicines
    if (companyIds.isNotEmpty) {
      final ph = List.filled(companyIds.length, '?').join(',');
      clauses.add(
        'orders.id IN ('
        'SELECT DISTINCT oi.order_id FROM order_items oi '
        'JOIN medicines m ON oi.medicine_id = m.id '
        'WHERE m.company_id IN ($ph))',
      );
      args.addAll(companyIds);
    }

    if (clauses.isEmpty) return (where: '', args: []);
    return (where: 'WHERE ${clauses.join(' AND ')}', args: args);
  }

  /// Builds extra AND conditions for the daily-orders query.
  /// (Date is already handled by the caller's SUBSTR date = ? clause.)
  ({String extra, List<Object?> args}) buildDailyExtra() {
    final clauses = <String>[];
    final args = <Object?>[];

    if (pharmacyIds.isNotEmpty) {
      final ph = List.filled(pharmacyIds.length, '?').join(',');
      clauses.add("orders.pharmacy_id IN ($ph)");
      args.addAll(pharmacyIds);
    }

    if (companyIds.isNotEmpty) {
      final ph = List.filled(companyIds.length, '?').join(',');
      clauses.add(
        'orders.id IN ('
        'SELECT DISTINCT oi.order_id FROM order_items oi '
        'JOIN medicines m ON oi.medicine_id = m.id '
        'WHERE m.company_id IN ($ph))',
      );
      args.addAll(companyIds);
    }

    if (clauses.isEmpty) return (extra: '', args: []);
    return (extra: 'AND ${clauses.join(' AND ')}', args: args);
  }

  // ── Display helpers ──────────────────────────────────────────────────

  /// Converts 'YYYY-MM' to an Arabic month + year label, e.g. 'أبريل 2026'.
  static String monthLabel(String yyyyMm) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    try {
      final p = yyyyMm.split('-');
      return '${months[int.parse(p[1]) - 1]} ${p[0]}';
    } catch (_) {
      return yyyyMm;
    }
  }
}


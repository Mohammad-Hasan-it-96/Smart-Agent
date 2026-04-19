import 'package:shared_preferences/shared_preferences.dart';

/// Generates unique invoice numbers in the format:
///   {userId}-{year}-{counter}
///   e.g.  42-2026-00001
///
/// * [userId]  — agent's userId returned from the activation API (stable per account)
/// * [year]    — 4-digit current year
/// * [counter] — zero-padded 5-digit sequential number, resets on new year
///
/// The counter is persisted in SharedPreferences under the key
///   invoice_counter_{year}
/// so it survives app restarts and is reset automatically each new year.
class InvoiceNumberService {
  static const String _counterKeyPrefix = 'invoice_counter_';
  static const String _userPrefixKey = 'invoice_user_prefix';

  final SharedPreferences _prefs;

  /// Optional clock override — used in tests to simulate a different year
  /// without changing any production behaviour.
  final DateTime Function() _clock;

  InvoiceNumberService(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now());

  /// Caches the userId prefix from [userId].
  /// Falls back to 'AGENT' when [userId] is empty.
  Future<void> initPrefix(String userId) async {
    final prefix = userId.isNotEmpty ? userId : 'AGENT';
    await _prefs.setString(_userPrefixKey, prefix);
  }

  /// Returns the userId prefix, always updating from [userId] when provided.
  Future<String> _getPrefix(String userId) async {
    if (userId.isNotEmpty) {
      await initPrefix(userId);
      return userId;
    }
    final cached = _prefs.getString(_userPrefixKey);
    if (cached != null && cached.isNotEmpty) return cached;
    return 'AGENT';
  }

  /// Generates the next invoice number and persists the incremented counter.
  /// [userId] is used as the prefix directly (full string, not derived from phone).
  Future<String> nextInvoiceNumber(String userId) async {
    final year = _clock().year;
    final counterKey = '$_counterKeyPrefix$year';

    final current = _prefs.getInt(counterKey) ?? 0;
    final next = current + 1;
    await _prefs.setInt(counterKey, next);

    final prefix = await _getPrefix(userId);
    final counter = next.toString().padLeft(5, '0');
    final invoiceNumber = '$prefix-$year-$counter';
    print('Generated invoice: $invoiceNumber');
    return invoiceNumber;
  }

  static Future<InvoiceNumberService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return InvoiceNumberService(prefs);
  }
}

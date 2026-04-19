import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_agent/core/services/invoice_number_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh [InvoiceNumberService] backed by in-memory SharedPreferences
/// and an injectable clock so tests can simulate any year.
Future<InvoiceNumberService> _makeService({
  required int year,
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initialPrefs));
  final prefs = await SharedPreferences.getInstance();
  return InvoiceNumberService(
    prefs,
    clock: () => DateTime(year, 6, 15), // fixed date within that year
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InvoiceNumberService — sequential numbering', () {
    test('first invoice starts at 00001', () async {
      final svc = await _makeService(year: 2026);
      expect(await svc.nextInvoiceNumber('42'), '42-2026-00001');
    });

    test('second invoice is 00002', () async {
      final svc = await _makeService(year: 2026);
      await svc.nextInvoiceNumber('42');
      expect(await svc.nextInvoiceNumber('42'), '42-2026-00002');
    });

    test('counter increments correctly across many calls', () async {
      final svc = await _makeService(year: 2026);
      for (int i = 1; i <= 5; i++) {
        final inv = await svc.nextInvoiceNumber('42');
        final expected = '42-2026-${i.toString().padLeft(5, '0')}';
        expect(inv, expected, reason: 'call #$i should produce $expected');
      }
    });

    test('counter is 5-digit zero-padded', () async {
      final svc = await _makeService(year: 2026);
      final inv = await svc.nextInvoiceNumber('42');
      // Format: prefix-year-00001
      final parts = inv.split('-');
      expect(parts.length, 3);
      expect(parts[2].length, 5);
      expect(parts[2], '00001');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('InvoiceNumberService — year rollover', () {
    test('counter resets to 00001 on new year', () async {
      // Simulate 2026 reaching counter 5
      final svc2026 = await _makeService(year: 2026);
      for (int i = 0; i < 5; i++) {
        await svc2026.nextInvoiceNumber('42');
      }

      // Now simulate 2027 — must start fresh at 00001
      final prefs = await SharedPreferences.getInstance();
      final svc2027 = InvoiceNumberService(
        prefs,
        clock: () => DateTime(2027, 1, 1),
      );
      expect(await svc2027.nextInvoiceNumber('42'), '42-2027-00001');
    });

    test('2026 counter is independent of 2027 counter', () async {
      final prefs2026 = await _makeService(year: 2026);
      await prefs2026.nextInvoiceNumber('42'); // 2026 → 1

      final prefs = await SharedPreferences.getInstance();

      final svc2027 = InvoiceNumberService(
        prefs,
        clock: () => DateTime(2027, 3, 10),
      );
      await svc2027.nextInvoiceNumber('42'); // 2027 → 1
      await svc2027.nextInvoiceNumber('42'); // 2027 → 2

      // Switch back to 2026 — should still be at 2
      final svc2026again = InvoiceNumberService(
        prefs,
        clock: () => DateTime(2026, 12, 31),
      );
      expect(
        await svc2026again.nextInvoiceNumber('42'),
        '42-2026-00002',
        reason: '2026 counter should continue from where it left off',
      );
    });

    test('first invoice of 2027 is 00001 even after 99999 invoices in 2026',
        () async {
      SharedPreferences.setMockInitialValues({
        'invoice_counter_2026': 99999,
      });
      final prefs = await SharedPreferences.getInstance();

      final svc2027 = InvoiceNumberService(
        prefs,
        clock: () => DateTime(2027, 1, 1),
      );
      expect(await svc2027.nextInvoiceNumber('42'), '42-2027-00001');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('InvoiceNumberService — prefix handling', () {
    test('uses userId as prefix', () async {
      final svc = await _makeService(year: 2026);
      expect(await svc.nextInvoiceNumber('99'), '99-2026-00001');
    });

    test('falls back to AGENT when userId is empty and no cached prefix',
        () async {
      final svc = await _makeService(year: 2026);
      expect(await svc.nextInvoiceNumber(''), 'AGENT-2026-00001');
    });

    test('uses cached prefix when userId is empty', () async {
      final svc = await _makeService(year: 2026);
      await svc.initPrefix('55'); // cache a prefix
      // Call with empty userId — should use cached '55'
      expect(await svc.nextInvoiceNumber(''), '55-2026-00001');
    });

    test('initPrefix updates the cached prefix', () async {
      final svc = await _makeService(year: 2026);
      await svc.initPrefix('10');
      await svc.initPrefix('20'); // override
      expect(await svc.nextInvoiceNumber(''), '20-2026-00001');
    });

    test('empty userId with initPrefix falls back to AGENT', () async {
      final svc = await _makeService(year: 2026);
      await svc.initPrefix(''); // empty → stored as AGENT
      expect(await svc.nextInvoiceNumber(''), 'AGENT-2026-00001');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('InvoiceNumberService — format', () {
    test('invoice format matches {prefix}-{year}-{5-digit counter}', () async {
      final svc = await _makeService(year: 2026);
      final inv = await svc.nextInvoiceNumber('42');
      final regex = RegExp(r'^[^-]+-\d{4}-\d{5}$');
      expect(regex.hasMatch(inv), isTrue,
          reason: '"$inv" does not match expected format');
    });

    test('year in invoice matches the clock year', () async {
      final svc = await _makeService(year: 2028);
      final inv = await svc.nextInvoiceNumber('7');
      expect(inv.split('-')[1], '2028');
    });
  });
}


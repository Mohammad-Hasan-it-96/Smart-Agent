import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_agent/core/services/bluetooth_print_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockBlueThermalPrinter extends Mock implements BlueThermalPrinter {}

// ---------------------------------------------------------------------------
// Fakes (needed by mocktail for sound null-safety with `any()`)
// ---------------------------------------------------------------------------

class FakeBluetoothDevice extends Fake implements BluetoothDevice {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBluetoothDevice());
  });
  late MockBlueThermalPrinter mockBt;
  late BluetoothPrintService service;

  setUp(() {
    mockBt = MockBlueThermalPrinter();
    service = BluetoothPrintService(bluetooth: mockBt);
  });

  group('BluetoothPrintService — initial state', () {
    test('isConnected is false on creation', () {
      expect(service.isConnected, isFalse);
    });

    test('connectedDevice is null on creation', () {
      expect(service.connectedDevice, isNull);
    });
  });

  group('BluetoothPrintService — getPairedDevices', () {
    test('returns empty list when underlying call throws', () async {
      when(() => mockBt.getBondedDevices())
          .thenThrow(Exception('Bluetooth off'));

      final devices = await service.getPairedDevices();
      expect(devices, isEmpty);
    });

    test('maps BluetoothDevice list to BtPrinterDevice list', () async {
      when(() => mockBt.getBondedDevices()).thenAnswer(
        (_) async => [
          BluetoothDevice('Printer A', '00:11:22:33:44:55'),
          BluetoothDevice('Printer B', 'AA:BB:CC:DD:EE:FF'),
        ],
      );

      final devices = await service.getPairedDevices();
      expect(devices, hasLength(2));
      expect(devices.first.name, 'Printer A');
      expect(devices.first.address, '00:11:22:33:44:55');
      expect(devices.last.name, 'Printer B');
    });

    test('filters out devices with null address', () async {
      when(() => mockBt.getBondedDevices()).thenAnswer(
        (_) async => [
          BluetoothDevice('Good Printer', '00:11:22:33:44:55'),
          BluetoothDevice('No Address', null),
        ],
      );

      final devices = await service.getPairedDevices();
      expect(devices, hasLength(1));
      expect(devices.first.name, 'Good Printer');
    });
  });

  group('BluetoothPrintService — connect / disconnect', () {
    const device =
        BtPrinterDevice(name: 'Test Printer', address: '00:11:22:33:44:55');

    test('connect returns true and updates state on success', () async {
      when(() => mockBt.connect(any())).thenAnswer((_) async {});
      when(() => mockBt.isConnected).thenAnswer((_) async => true);

      final result = await service.connect(device);

      expect(result, isTrue);
      expect(service.isConnected, isTrue);
      expect(service.connectedDevice, device);
    });

    test('connect returns false and leaves state clean when BT throws',
        () async {
      when(() => mockBt.connect(any()))
          .thenThrow(Exception('Connection refused'));

      final result = await service.connect(device);

      expect(result, isFalse);
      expect(service.isConnected, isFalse);
      expect(service.connectedDevice, isNull);
    });

    test('disconnect clears connection state', () async {
      // First connect
      when(() => mockBt.connect(any())).thenAnswer((_) async {});
      when(() => mockBt.isConnected).thenAnswer((_) async => true);
      await service.connect(device);

      // Then disconnect
      when(() => mockBt.disconnect()).thenAnswer((_) async => true);
      await service.disconnect();

      expect(service.isConnected, isFalse);
      expect(service.connectedDevice, isNull);
    });
  });

  group('BluetoothPrintService — printOrderInvoice', () {
    const device =
        BtPrinterDevice(name: 'Test Printer', address: '00:11:22:33:44:55');

    setUp(() async {
      when(() => mockBt.connect(any())).thenAnswer((_) async {});
      when(() => mockBt.isConnected).thenAnswer((_) async => true);
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockBt.printNewLine()).thenAnswer((_) async {});
      await service.connect(device);
    });

    test('throws StateError when not connected', () {
      final disconnected = BluetoothPrintService(bluetooth: mockBt);
      expect(
        () => disconnected.printOrderInvoice(
          pharmacyName: 'Test',
          orderDate: '2026/01/01',
          items: [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('calls printCustom and printNewLine for a non-empty item list',
        () async {
      await service.printOrderInvoice(
        pharmacyName: 'Pharmacy A',
        orderDate: '2026/01/01 10:00',
        items: [
          {'medicine_name': 'Drug A', 'qty': 5, 'gift_qty': 0, 'is_gift': 0},
          {'medicine_name': 'Drug B', 'qty': 3, 'gift_qty': 2, 'is_gift': 0},
        ],
      );

      verify(() => mockBt.printCustom(any(), any(), any()))
          .called(greaterThan(0));
      verify(() => mockBt.printNewLine()).called(greaterThan(0));
    });

    test('handles empty items list without throwing', () async {
      await expectLater(
        service.printOrderInvoice(
          pharmacyName: 'Empty Pharmacy',
          orderDate: '2026/01/01',
          items: [],
        ),
        completes,
      );
    });

    test('handles gift-only item (is_gift == 1)', () async {
      await expectLater(
        service.printOrderInvoice(
          pharmacyName: 'Pharmacy',
          orderDate: '2026/01/01',
          items: [
            {'medicine_name': 'Gift Drug', 'qty': 0, 'gift_qty': 5, 'is_gift': 1},
          ],
        ),
        completes,
      );
    });
  });

  group('BluetoothPrintService — printing guards', () {
    test('printTestPage throws StateError when not connected', () async {
      expect(
        () => service.printTestPage(),
        throwsA(isA<StateError>()),
      );
    });

    test('printText throws StateError when not connected', () async {
      expect(
        () => service.printText('hello'),
        throwsA(isA<StateError>()),
      );
    });

    test('feedLines throws StateError when not connected', () async {
      expect(
        () => service.feedLines(2),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── Sprint 5.3 — preferred printer storage ────────────────────────────────

  group('BluetoothPrintService — preferred printer', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadPreferredPrinter returns null when nothing saved', () async {
      final result = await service.loadPreferredPrinter();
      expect(result, isNull);
    });

    test('savePreferredPrinter then loadPreferredPrinter round-trips device',
        () async {
      const device =
          BtPrinterDevice(name: 'My Printer', address: '11:22:33:44:55:66');
      await service.savePreferredPrinter(device);

      final loaded = await service.loadPreferredPrinter();
      expect(loaded?.address, device.address);
      expect(loaded?.name, device.name);
    });

    test('overwriting preferred printer saves the new one', () async {
      const first =
          BtPrinterDevice(name: 'Printer A', address: 'AA:BB:CC:DD:EE:01');
      const second =
          BtPrinterDevice(name: 'Printer B', address: 'AA:BB:CC:DD:EE:02');

      await service.savePreferredPrinter(first);
      await service.savePreferredPrinter(second);

      final loaded = await service.loadPreferredPrinter();
      expect(loaded?.address, second.address);
    });

    test('connectToPreferred returns false when no printer saved', () async {
      final result = await service.connectToPreferred();
      expect(result, isFalse);
    });

    test(
        'connectToPreferred returns false when saved printer is not in paired list',
        () async {
      const device =
          BtPrinterDevice(name: 'Old Printer', address: 'AA:BB:CC:DD:EE:FF');
      await service.savePreferredPrinter(device);

      when(() => mockBt.getBondedDevices()).thenAnswer((_) async => []);

      final result = await service.connectToPreferred();
      expect(result, isFalse);
      expect(service.isConnected, isFalse);
    });

    test(
        'connectToPreferred connects when saved printer is found in paired list',
        () async {
      const savedDevice =
          BtPrinterDevice(name: 'My Printer', address: '11:22:33:44:55:66');
      await service.savePreferredPrinter(savedDevice);

      when(() => mockBt.getBondedDevices()).thenAnswer(
        (_) async => [BluetoothDevice('My Printer', '11:22:33:44:55:66')],
      );
      when(() => mockBt.connect(any())).thenAnswer((_) async {});
      when(() => mockBt.isConnected).thenAnswer((_) async => true);

      final result = await service.connectToPreferred();
      expect(result, isTrue);
      expect(service.isConnected, isTrue);
      expect(service.connectedDevice?.address, '11:22:33:44:55:66');
    });
  });

  // ── Sprint 5.3 — invoice format ───────────────────────────────────────────

  group('BluetoothPrintService — invoice format', () {
    const device =
        BtPrinterDevice(name: 'Test Printer', address: '00:11:22:33:44:55');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      when(() => mockBt.connect(any())).thenAnswer((_) async {});
      when(() => mockBt.isConnected).thenAnswer((_) async => true);
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockBt.printNewLine()).thenAnswer((_) async {});
      await service.connect(device);
    });

    test('each item line is exactly 32 characters wide', () async {
      final lines = <String>[];
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((inv) async {
        lines.add(inv.positionalArguments[0] as String);
      });

      await service.printOrderInvoice(
        pharmacyName: 'Test',
        orderDate: '2026/01/01',
        items: [
          {'medicine_name': 'Amoxicillin Cap', 'qty': 10, 'gift_qty': 0, 'is_gift': 0},
          {'medicine_name': 'A Very Long Medicine Name That Should Be Truncated', 'qty': 5, 'gift_qty': 2, 'is_gift': 0},
          {'medicine_name': 'Gift Item', 'qty': 0, 'gift_qty': 3, 'is_gift': 1},
        ],
      );

      // Every item row (not separator or header meta) must be 32 chars
      final itemRows = lines.where((l) =>
          l.isNotEmpty &&
          !l.startsWith('=') &&
          !l.startsWith('-') &&
          !l.startsWith('Pharmacy') &&
          !l.startsWith('Date') &&
          !l.startsWith('Agent') &&
          !l.startsWith('Lines') &&
          !l.startsWith('Total') &&
          !l.startsWith('Smart') &&
          !l.startsWith(' #')).toList();

      for (final row in itemRows) {
        expect(row.length, 32,
            reason: 'Item row "$row" should be exactly 32 chars');
      }
    });

    test('invoice includes column header line with Item and Qty', () async {
      final lines = <String>[];
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((inv) async {
        lines.add(inv.positionalArguments[0] as String);
      });

      await service.printOrderInvoice(
        pharmacyName: 'P', orderDate: 'D', items: [],
      );

      expect(lines.any((l) => l.contains('Item') && l.contains('Qty')), isTrue);
    });

    test('agentName line appears when agent is provided', () async {
      final lines = <String>[];
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((inv) async {
        lines.add(inv.positionalArguments[0] as String);
      });

      await service.printOrderInvoice(
        pharmacyName: 'P',
        orderDate: 'D',
        items: [],
        agentName: 'Ahmed Ali',
      );

      expect(lines.any((l) => l.contains('Agent') && l.contains('Ahmed Ali')),
          isTrue);
    });

    test('agentName line is omitted when agent is null or empty', () async {
      final lines = <String>[];
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((inv) async {
        lines.add(inv.positionalArguments[0] as String);
      });

      await service.printOrderInvoice(
        pharmacyName: 'P', orderDate: 'D', items: [], agentName: null,
      );

      expect(lines.any((l) => l.startsWith('Agent')), isFalse);
    });

    test('footer shows correct line count and total qty', () async {
      final lines = <String>[];
      when(() => mockBt.printCustom(any(), any(), any()))
          .thenAnswer((inv) async {
        lines.add(inv.positionalArguments[0] as String);
      });

      await service.printOrderInvoice(
        pharmacyName: 'P',
        orderDate: 'D',
        items: [
          {'medicine_name': 'A', 'qty': 3, 'gift_qty': 1, 'is_gift': 0},
          {'medicine_name': 'B', 'qty': 7, 'gift_qty': 0, 'is_gift': 0},
        ],
      );

      expect(lines.any((l) => l.contains('Lines') && l.contains('2')), isTrue);
      expect(lines.any((l) => l.contains('Total Qty') && l.contains('11')),
          isTrue); // 3+1+7 = 11
    });

    test('BtPrinterDevice equality is based on address', () {
      const a = BtPrinterDevice(name: 'X', address: '11:22:33:44:55:66');
      const b = BtPrinterDevice(name: 'Y', address: '11:22:33:44:55:66');
      const c = BtPrinterDevice(name: 'X', address: 'AA:BB:CC:DD:EE:FF');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}


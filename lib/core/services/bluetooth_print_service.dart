import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight model that surfaces the printer name + MAC address to the UI
/// without leaking the package's [BluetoothDevice] directly.
class BtPrinterDevice {
  final String name;
  final String address;

  const BtPrinterDevice({required this.name, required this.address});

  @override
  String toString() => '$name ($address)';

  @override
  bool operator ==(Object other) =>
      other is BtPrinterDevice && other.address == address;

  @override
  int get hashCode => address.hashCode;
}

/// Wraps [BlueThermalPrinter] and exposes a clean, testable API for the rest
/// of the app.  Extends [ChangeNotifier] so any widget / provider that holds
/// this service can rebuild when the connection state changes.
///
/// Usage:
/// ```dart
/// final service = getIt<BluetoothPrintService>();
/// final devices  = await service.getPairedDevices();
/// await service.connect(devices.first);
/// await service.printTestPage();
/// await service.disconnect();
/// ```
class BluetoothPrintService extends ChangeNotifier {
  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _kPrinterAddressKey = 'bt_preferred_printer_address';
  static const String _kPrinterNameKey = 'bt_preferred_printer_name';

  // ── Invoice layout constants (32 chars ≈ 58 mm paper) ────────────────────
  static const int _kIdxWidth = 3;    //  " 1."  or "10."
  static const int _kNameWidth = 20;  //  medicine name column
  static const int _kQtyWidth = 7;    //  quantity column (right-aligned)
  // _kIdxWidth(3) + 1 + _kNameWidth(20) + 1 + _kQtyWidth(7) = 32 chars total
  static const String _kOuterSep = '================================'; // 32 =
  static const String _kInnerSep = '--------------------------------'; // 32 -

  /// Pass a custom [BlueThermalPrinter] in tests to allow mocking.
  BluetoothPrintService({BlueThermalPrinter? bluetooth})
      : _bt = bluetooth ?? BlueThermalPrinter.instance;

  final BlueThermalPrinter _bt;

  BtPrinterDevice? _connectedDevice;
  bool _isConnected = false;

  // ── Public state ──────────────────────────────────────────────────────────

  /// The currently connected printer, or `null` when disconnected.
  BtPrinterDevice? get connectedDevice => _connectedDevice;

  /// Whether an active Classic-BT connection exists.
  bool get isConnected => _isConnected;

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Returns all paired / bonded Bluetooth devices visible to Android.
  Future<List<BtPrinterDevice>> getPairedDevices() async {
    try {
      final rawList = await _bt.getBondedDevices();
      return rawList
          .where((d) => d.address != null)
          .map(
            (d) => BtPrinterDevice(
              name: d.name ?? 'Unknown',
              address: d.address!,
            ),
          )
          .toList();
    } catch (e) {
      _debugLog('getPairedDevices error: $e');
      return [];
    }
  }

  // ── Connection management ─────────────────────────────────────────────────

  /// Connects to the printer at [device.address].
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> connect(BtPrinterDevice device) async {
    try {
      final btDevice = BluetoothDevice(device.name, device.address);
      await _bt.connect(btDevice);
      _isConnected = (await _bt.isConnected) ?? false;
      if (_isConnected) {
        _connectedDevice = device;
        notifyListeners();
      }
      return _isConnected;
    } catch (e) {
      _debugLog('connect error: $e');
      return false;
    }
  }

  /// Disconnects from the current printer and clears state.
  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (e) {
      _debugLog('disconnect error: $e');
    } finally {
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  /// Queries the BT stack for the real connection status and updates state.
  Future<bool> refreshConnectionState() async {
    _isConnected = (await _bt.isConnected) ?? false;
    if (!_isConnected) _connectedDevice = null;
    notifyListeners();
    return _isConnected;
  }

  // ── Preferred printer storage ─────────────────────────────────────────────

  /// Persists [device] address and name so it can be reconnected automatically
  /// on the next print without asking the user to pick again.
  Future<void> savePreferredPrinter(BtPrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterAddressKey, device.address);
    await prefs.setString(_kPrinterNameKey, device.name);
    _debugLog('Saved preferred printer: ${device.name} (${device.address})');
  }

  /// Loads the previously saved preferred printer, or `null` if none is saved.
  Future<BtPrinterDevice?> loadPreferredPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_kPrinterAddressKey);
    if (address == null || address.isEmpty) return null;
    final name = prefs.getString(_kPrinterNameKey) ?? 'Saved Printer';
    return BtPrinterDevice(name: name, address: address);
  }

  /// Silently tries to connect to the last-used printer.
  ///
  /// Returns `true` when the printer is found in the paired list **and** the
  /// connection succeeds.  Returns `false` in all other cases (no saved
  /// printer, not paired, connection error) without throwing.
  Future<bool> connectToPreferred() async {
    final preferred = await loadPreferredPrinter();
    if (preferred == null) return false;

    final paired = await getPairedDevices();
    final match = paired.cast<BtPrinterDevice?>().firstWhere(
          (d) => d?.address == preferred.address,
          orElse: () => null,
        );

    if (match == null) {
      _debugLog(
          'Preferred printer ${preferred.address} not in paired list — skipping auto-connect');
      return false;
    }

    return connect(match);
  }

  // ── Printing ──────────────────────────────────────────────────────────────

  /// Sends a test page to verify that the printer is reachable and working.
  ///
  /// Throws [StateError] if not connected.
  Future<void> printTestPage() async {
    _assertConnected();
    await _bt.printCustom(_kOuterSep, 1, 1);
    await _bt.printNewLine();
    await _bt.printCustom('TEST PRINT', 2, 1);
    await _bt.printNewLine();
    await _bt.printCustom('Smart Agent', 1, 1);
    await _bt.printNewLine();
    await _bt.printCustom(_kOuterSep, 1, 1);
    await _bt.printNewLine();
    await _bt.printCustom('Printer is working correctly.', 1, 1);
    await _bt.printNewLine();
    await _bt.printNewLine();
    await _bt.printNewLine();
  }

  /// Prints a single line of [text].
  ///
  /// [size]  — 1 = normal, 2 = large, 3 = extra-large.
  /// [align] — 0 = left, 1 = center, 2 = right.
  ///
  /// Throws [StateError] if not connected.
  Future<void> printText(
    String text, {
    int size = 1,
    int align = 0,
  }) async {
    _assertConnected();
    await _bt.printCustom(text, size, align);
  }

  /// Prints a complete order invoice with aligned columns.
  ///
  /// Layout (32-char / 58 mm paper):
  /// ```
  /// ================================
  ///         Smart Agent
  /// ================================
  /// Pharmacy : <pharmacyName>
  /// Date     : <orderDate>
  /// Agent    : <agentName>       ← only if [agentName] is non-empty
  /// ================================
  ///  #  Item                    Qty
  /// --------------------------------
  ///  1. <name padded to 20>  <qty r>
  ///  2. <name>               <qty r>
  /// --------------------------------
  /// Lines    : N
  /// Total Qty: T
  /// ================================
  /// ```
  ///
  /// Expected keys per item map:
  ///   `medicine_name` (String), `qty` (num), `gift_qty` (num), `is_gift` (int 0/1)
  ///
  /// Throws [StateError] if not connected.
  Future<void> printOrderInvoice({
    required String pharmacyName,
    required String orderDate,
    required List<Map<String, dynamic>> items,
    String? agentName,
  }) async {
    _assertConnected();

    // ── Header ────────────────────────────────────────────────────────────
    await _bt.printCustom(_kOuterSep, 1, 1);
    await _bt.printCustom('Smart Agent', 2, 1);
    await _bt.printNewLine();

    // ── Order meta ────────────────────────────────────────────────────────
    await _bt.printCustom('Pharmacy : $pharmacyName', 1, 0);
    await _bt.printCustom('Date     : $orderDate', 1, 0);
    if (agentName != null && agentName.isNotEmpty) {
      await _bt.printCustom('Agent    : $agentName', 1, 0);
    }
    await _bt.printCustom(_kOuterSep, 1, 1);

    // ── Column header ─────────────────────────────────────────────────────
    await _bt.printCustom(_columnHeaderLine(), 1, 0);
    await _bt.printCustom(_kInnerSep, 1, 1);

    // ── Items ─────────────────────────────────────────────────────────────
    int totalQty = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final name = (item['medicine_name'] as String?) ?? '';
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final giftQty = (item['gift_qty'] as num?)?.toInt() ?? 0;
      final isGift = (item['is_gift'] as int? ?? 0) == 1;

      totalQty += qty + giftQty;

      final qtyLabel = isGift
          ? 'Gift'
          : (giftQty > 0 ? '$qty+${giftQty}G' : '$qty');

      await _bt.printCustom(_itemLine(i + 1, name, qtyLabel), 1, 0);
    }

    // ── Footer ────────────────────────────────────────────────────────────
    await _bt.printCustom(_kInnerSep, 1, 1);
    await _bt.printCustom('Lines    : ${items.length}', 1, 0);
    await _bt.printCustom('Total Qty: $totalQty', 1, 0);
    await _bt.printCustom(_kOuterSep, 1, 1);

    // Paper feed
    await _bt.printNewLine();
    await _bt.printNewLine();
    await _bt.printNewLine();
  }

  /// Advances the paper by printing [lines] empty lines.
  ///
  /// Throws [StateError] if not connected.
  Future<void> feedLines([int lines = 1]) async {
    _assertConnected();
    for (var i = 0; i < lines; i++) {
      await _bt.printNewLine();
    }
  }

  // ── Invoice layout helpers ────────────────────────────────────────────────

  /// Returns the column-header line:  " #  Item                    Qty"
  String _columnHeaderLine() {
    final idx = _padL(' #', _kIdxWidth);
    final name = _padR('Item', _kNameWidth);
    final qty = _padL('Qty', _kQtyWidth);
    return '$idx $name $qty';
  }

  /// Returns a single formatted item line with fixed-width columns.
  String _itemLine(int index, String name, String qtyLabel) {
    final idxStr = _padL('$index.', _kIdxWidth);
    final nameStr = _padR(_truncate(name, _kNameWidth), _kNameWidth);
    final qtyStr = _padL(qtyLabel, _kQtyWidth);
    return '$idxStr $nameStr $qtyStr';
  }

  static String _padR(String s, int w) =>
      s.length >= w ? s.substring(0, w) : s.padRight(w);

  static String _padL(String s, int w) =>
      s.length >= w ? s.substring(0, w) : s.padLeft(w);

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 2)}..';

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _assertConnected() {
    if (!_isConnected) {
      throw StateError(
        'BluetoothPrintService: no active printer connection. '
        'Call connect() first.',
      );
    }
  }

  void _debugLog(String msg) {
    assert(() {
      // ignore: avoid_print
      print('[BluetoothPrintService] $msg');
      return true;
    }());
  }
}


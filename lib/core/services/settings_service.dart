import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/warehouse.dart';

class SettingsService {
  static const String defaultApiBaseUrl =
      'https://harrypotter.foodsalebot.com/api';
  static const String defaultSupportEmail = 'smart.agent.app.support@gmail.com';
  static const String defaultSupportTelegram = 'https://t.me/+963959027196';
  static const String defaultSupportWhatsapp = '963959027196';
  static const String _enablePricesKey = 'settings_enable_prices';
  static const String _currencyModeKey = 'settings_currency_mode';
  static const String _exchangeRateKey = 'settings_exchange_rate';
  static const String _inventoryPhoneKey = 'settings_inventory_phone';
  static const String _apiBaseUrlKey = 'settings_api_base_url';
  static const String _warehouse1Key = 'settings_warehouse_1';
  static const String _warehouse2Key = 'settings_warehouse_2';
  static const String _warehouse3Key = 'settings_warehouse_3';
  static const String _supportEmailKey = 'settings_support_email';
  static const String _supportTelegramKey = 'settings_support_telegram';
  static const String _supportWhatsappKey = 'settings_support_whatsapp';

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return defaultApiBaseUrl;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeBaseUrl(url);
    if (normalized == defaultApiBaseUrl) {
      await prefs.remove(_apiBaseUrlKey);
      return;
    }
    await prefs.setString(_apiBaseUrlKey, normalized);
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiBaseUrlKey);
    return _normalizeBaseUrl(saved ?? defaultApiBaseUrl);
  }

  static Future<Uri> buildApiUri(String endpoint) async {
    final baseUrl = await getApiBaseUrl();
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$baseUrl/$cleanEndpoint');
  }

  static String _normalizeSupportValue(String value) => value.trim();

  static Future<void> setSupportInfo({
    String? email,
    String? telegram,
    String? whatsapp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (email != null) {
      final value = _normalizeSupportValue(email);
      if (value.isEmpty) {
        await prefs.remove(_supportEmailKey);
      } else {
        await prefs.setString(_supportEmailKey, value);
      }
    }
    if (telegram != null) {
      final value = _normalizeSupportValue(telegram);
      if (value.isEmpty) {
        await prefs.remove(_supportTelegramKey);
      } else {
        await prefs.setString(_supportTelegramKey, value);
      }
    }
    if (whatsapp != null) {
      final value = _normalizeSupportValue(whatsapp);
      if (value.isEmpty) {
        await prefs.remove(_supportWhatsappKey);
      } else {
        await prefs.setString(_supportWhatsappKey, value);
      }
    }
  }

  static Future<SupportContactInfo> getSupportInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return SupportContactInfo(
      email: (prefs.getString(_supportEmailKey) ?? defaultSupportEmail).trim(),
      telegram:
          (prefs.getString(_supportTelegramKey) ?? defaultSupportTelegram).trim(),
      whatsapp:
          (prefs.getString(_supportWhatsappKey) ?? defaultSupportWhatsapp).trim(),
    );
  }

  // Check if pricing is enabled
  Future<bool> isPricingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enablePricesKey) ?? false;
  }

  // Get currency mode (usd or syp)
  Future<String> getCurrencyMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyModeKey) ?? 'usd';
  }

  // Get exchange rate (USD to SYP)
  Future<double> getExchangeRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_exchangeRateKey) ?? 1.0;
  }

  // Save pricing enabled state
  Future<void> setPricingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enablePricesKey, enabled);
  }

  // Save currency mode
  Future<void> setCurrencyMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyModeKey, mode);
  }

  // Save exchange rate
  Future<void> setExchangeRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_exchangeRateKey, rate);
  }

  // ── Warehouse storage (unified model) ──────────────────────────────
  static const String _warehousesV2Key = 'settings_warehouses_v2';
  static const int maxWarehouses = 4;

  // Inventory WhatsApp phone number — DEPRECATED, use getWarehouseList()
  // Kept for backward-compat migration only.
  Future<String> getInventoryPhone() async {
    final list = await getWarehouseList();
    return list.isNotEmpty ? list.first.phone : '';
  }

  Future<void> setInventoryPhone(String phone) async {
    // Migrate: update warehouse 1 phone, keep existing name
    final list = await getWarehouseList();
    final updated = List<Warehouse>.from(list);
    if (updated.isEmpty) {
      updated.add(Warehouse(name: 'المستودع الرئيسي', phone: phone.trim()));
    } else {
      updated[0] = updated[0].copyWith(phone: phone.trim());
    }
    await setWarehouseList(updated);
  }

  // ── Unified warehouse list ─────────────────────────────────────────

  /// Returns up to [maxWarehouses] warehouses, migrating old keys on first call.
  Future<List<Warehouse>> getWarehouseList() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_warehousesV2Key);
    if (json != null) {
      try {
        final list = (jsonDecode(json) as List)
            .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
            .toList();
        // Pad to maxWarehouses
        while (list.length < maxWarehouses) {
          list.add(const Warehouse());
        }
        return list.sublist(0, maxWarehouses);
      } catch (_) {}
    }
    // ── Migration from old keys ──────────────────────────────────────
    final oldInvPhone = prefs.getString(_inventoryPhoneKey) ?? '';
    final oldWh1 = prefs.getString(_warehouse1Key) ?? '';
    final oldWh2 = prefs.getString(_warehouse2Key) ?? '';
    final oldWh3 = prefs.getString(_warehouse3Key) ?? '';

    final migrated = <Warehouse>[
      Warehouse(
        name: oldInvPhone.trim().isNotEmpty ? 'المستودع الرئيسي' : '',
        phone: oldInvPhone.trim(),
      ),
      Warehouse(name: oldWh1.trim().isNotEmpty ? 'مستودع 2' : '', phone: oldWh1.trim()),
      Warehouse(name: oldWh2.trim().isNotEmpty ? 'مستودع 3' : '', phone: oldWh2.trim()),
      Warehouse(name: oldWh3.trim().isNotEmpty ? 'مستودع 4' : '', phone: oldWh3.trim()),
    ];

    // Persist migrated data and clean up old keys
    await _saveWarehouseJson(prefs, migrated);
    await prefs.remove(_inventoryPhoneKey);
    await prefs.remove(_warehouse1Key);
    await prefs.remove(_warehouse2Key);
    await prefs.remove(_warehouse3Key);

    return migrated;
  }

  Future<void> setWarehouseList(List<Warehouse> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveWarehouseJson(prefs, list);
  }

  Future<void> _saveWarehouseJson(SharedPreferences prefs, List<Warehouse> list) async {
    final padded = List<Warehouse>.from(list);
    while (padded.length < maxWarehouses) {
      padded.add(const Warehouse());
    }
    final json = jsonEncode(padded.sublist(0, maxWarehouses).map((w) => w.toJson()).toList());
    await prefs.setString(_warehousesV2Key, json);
  }

  // Legacy getters kept for compile-compat — delegate to unified list
  Future<List<String>> getWarehouses() async {
    final list = await getWarehouseList();
    return list.map((w) => w.phone).toList();
  }

  Future<void> setWarehouse(int index, String phone) async {
    final list = await getWarehouseList();
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(phone: phone.trim());
      await setWarehouseList(list);
    }
  }
}

class SupportContactInfo {
  final String email;
  final String telegram;
  final String whatsapp;

  const SupportContactInfo({
    required this.email,
    required this.telegram,
    required this.whatsapp,
  });
}


import 'package:shared_preferences/shared_preferences.dart';

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

  // Inventory WhatsApp phone number (for warehouse)
  Future<String> getInventoryPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_inventoryPhoneKey) ?? '';
  }

  Future<void> setInventoryPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    if (phone.trim().isEmpty) {
      await prefs.remove(_inventoryPhoneKey);
    } else {
      await prefs.setString(_inventoryPhoneKey, phone.trim());
    }
  }

  // Convert USD value to display currency
  Future<double> convertToDisplayCurrency(double usdValue) async {
    final mode = await getCurrencyMode();
    if (mode == 'syp') {
      final rate = await getExchangeRate();
      return usdValue * rate;
    }
    return usdValue;
  }

  // Get currency symbol
  Future<String> getCurrencySymbol() async {
    final mode = await getCurrencyMode();
    return mode == 'syp' ? 'ل.س' : '\$';
  }

  // Format price with currency symbol
  Future<String> formatPrice(double price) async {
    final symbol = await getCurrencySymbol();
    final displayPrice = await convertToDisplayCurrency(price);
    return '$displayPrice $symbol';
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


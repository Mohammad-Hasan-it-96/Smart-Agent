import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String defaultApiBaseUrl =
      'https://harrypotter.foodsalebot.com/api';
  static const String _enablePricesKey = 'settings_enable_prices';
  static const String _currencyModeKey = 'settings_currency_mode';
  static const String _exchangeRateKey = 'settings_exchange_rate';
  static const String _inventoryPhoneKey = 'settings_inventory_phone';
  static const String _apiBaseUrlKey = 'settings_api_base_url';

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


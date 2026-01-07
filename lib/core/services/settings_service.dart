import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _enablePricesKey = 'settings_enable_prices';
  static const String _currencyModeKey = 'settings_currency_mode';
  static const String _exchangeRateKey = 'settings_exchange_rate';
  static const String _inventoryPhoneKey = 'settings_inventory_phone';

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


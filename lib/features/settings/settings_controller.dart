import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_logger.dart';

class SettingsData {
  String agentName;
  String agentPhone;
  String inventoryPhone;
  String deviceId;
  bool isActivated;
  String? expiresAt;
  String? selectedPlan;
  bool pricingEnabled;
  String currencyMode;
  double exchangeRate;
  int pdfFontSize;
  bool enableGifts;
  bool hideCarousel;

  SettingsData({
    this.agentName = '',
    this.agentPhone = '',
    this.inventoryPhone = '',
    this.deviceId = '',
    this.isActivated = false,
    this.expiresAt,
    this.selectedPlan,
    this.pricingEnabled = false,
    this.currencyMode = 'usd',
    this.exchangeRate = 1.0,
    this.pdfFontSize = 12,
    this.enableGifts = false,
    this.hideCarousel = false,
  });
}

class SettingsController extends ChangeNotifier {
  final ActivationService _activation = getIt<ActivationService>();
  final SettingsService _settings = getIt<SettingsService>();

  SettingsData data = SettingsData();
  bool isLoading = true;
  bool isSavingAccount = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      data.agentName = await _activation.getAgentName();
      data.agentPhone = await _activation.getAgentPhone();
      data.inventoryPhone = await _settings.getInventoryPhone();
      data.deviceId = await _activation.getDeviceId();
      data.isActivated = await _activation.isActivated();
      data.expiresAt = await _activation.getExpiresAt();
      data.selectedPlan = await _activation.getSelectedPlan();
      data.pricingEnabled = await _settings.isPricingEnabled();
      data.currencyMode = await _settings.getCurrencyMode();
      data.exchangeRate = await _settings.getExchangeRate();
      data.pdfFontSize = prefs.getInt(AppConstants.kPdfFontSize) ?? 12;
      data.enableGifts = prefs.getBool(AppConstants.kEnableGifts) ?? false;
      data.hideCarousel = prefs.getBool(AppConstants.kHideHomeCarousel) ?? false;
    } catch (e) {
      AppLogger.e('SettingsController', 'load failed', e);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> saveAccount(String name, String phone, String inv) async {
    isSavingAccount = true;
    notifyListeners();
    bool serverOk = false;
    try {
      await _activation.saveAgentName(name);
      await _activation.saveAgentPhone(phone);
      await _settings.setInventoryPhone(inv);
      data.agentName = name;
      data.agentPhone = phone;
      data.inventoryPhone = inv;
      try {
        serverOk = await _activation.updateMyData(name, phone);
      } catch (e) {
        // Local data was saved successfully. The server sync failed (e.g. offline).
        // The caller receives serverOk=false so it can inform the user.
        AppLogger.w('SettingsController', 'updateMyData server sync failed', e);
      }
    } catch (e) {
      AppLogger.e('SettingsController', 'saveAccount local persist failed', e);
      isSavingAccount = false;
      notifyListeners();
      return false;
    }
    isSavingAccount = false;
    notifyListeners();
    return serverOk;
  }

  Future<bool> recheckActivation() async {
    final verified = await _activation.recheckActivationStatus();
    data.isActivated = await _activation.isActivated();
    data.expiresAt = await _activation.getExpiresAt();
    data.selectedPlan = await _activation.getSelectedPlan();
    notifyListeners();
    return verified;
  }

  Future<void> setPricingEnabled(bool v) async {
    data.pricingEnabled = v;
    await _settings.setPricingEnabled(v);
    notifyListeners();
  }

  Future<void> setCurrencyMode(String mode) async {
    data.currencyMode = mode;
    await _settings.setCurrencyMode(mode);
    notifyListeners();
  }

  Future<void> setExchangeRate(double rate) async {
    data.exchangeRate = rate;
    await _settings.setExchangeRate(rate);
    notifyListeners();
  }

  Future<void> setPdfFontSize(int size) async {
    data.pdfFontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.kPdfFontSize, size);
    notifyListeners();
  }

  Future<void> setEnableGifts(bool v) async {
    data.enableGifts = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kEnableGifts, v);
    notifyListeners();
  }

  Future<void> setHideCarousel(bool v) async {
    data.hideCarousel = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kHideHomeCarousel, v);
    notifyListeners();
  }
}

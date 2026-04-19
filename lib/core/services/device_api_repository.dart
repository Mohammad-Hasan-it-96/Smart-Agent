import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'settings_service.dart';

/// Handles all remote HTTP communication with the activation backend.
///
/// Each method maps to one API endpoint. Methods return decoded response data
/// (or a typed result for simple cases) so that [ActivationService] can apply
/// business logic without knowing about HTTP internals.
///
/// Error contract:
///   - Network / timeout errors → always rethrown (let the caller decide).
///   - Non-success HTTP status → throws or returns null as documented per method.
class DeviceApiRepository {
  // ── Endpoint names ────────────────────────────────────────────────────
  static const String _createDeviceEndpoint = 'create_device';
  static const String _checkDeviceEndpoint = 'check_device';
  static const String _updateMyDataEndpoint = 'update_my_data';

  Future<Uri> _apiUri(String endpoint) => SettingsService.buildApiUri(endpoint);

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  // ── createDevice ──────────────────────────────────────────────────────

  /// Registers a new device / sends the initial activation request.
  ///
  /// Returns the decoded JSON response body on HTTP 200.
  /// Throws an [Exception] on any non-200 status or network failure.
  Future<Map<String, dynamic>> createDevice({
    required String deviceId,
    required String fullName,
    required String phone,
  }) async {
    final body = jsonEncode({
      'app_name': AppConstants.appName,
      'device_id': deviceId,
      'full_name': fullName,
      'phone': phone,
    });

    final response = await http
        .post(await _apiUri(_createDeviceEndpoint),
            headers: _jsonHeaders, body: body)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Connection timeout'),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Server returned status code: ${response.statusCode}');
  }

  // ── checkDevice ───────────────────────────────────────────────────────

  /// Checks the activation / subscription status of a device on the server.
  ///
  /// Returns the decoded JSON body on HTTP 200.
  /// Returns `null` on any non-200 status (treat as "not verified").
  /// Rethrows network / timeout errors.
  Future<Map<String, dynamic>?> checkDevice({
    required String deviceId,
  }) async {
    final body = jsonEncode({
      'device_id': deviceId,
      'app_name': AppConstants.appName,
    });

    final response = await http
        .post(await _apiUri(_checkDeviceEndpoint),
            headers: _jsonHeaders, body: body)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Connection timeout'),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null; // non-200 → caller treats as unverified
  }

  // ── updateMyData ──────────────────────────────────────────────────────

  /// Pushes updated agent name / phone to the server.
  ///
  /// Returns `true` if the server acknowledges success.
  /// Returns `false` on non-200 status.
  /// Rethrows network / timeout errors.
  Future<bool> updateMyData({
    required String deviceId,
    required String fullName,
    required String phone,
  }) async {
    final body = jsonEncode({
      'device_id': deviceId,
      'app_name': AppConstants.appName,
      'full_name': fullName,
      'phone': phone,
    });

    final response = await http
        .post(await _apiUri(_updateMyDataEndpoint),
            headers: _jsonHeaders, body: body)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Connection timeout'),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true || data['success'] == 1;
    }
    return false;
  }

  // ── addReview ─────────────────────────────────────────────────────────

  /// Posts a star rating and optional comment for the device.
  ///
  /// Returns `true` on HTTP 200/201.
  /// Returns `false` on non-2xx.
  /// Rethrows network / timeout errors.
  Future<bool> addReview({
    required String deviceId,
    required int stars,
    String? comment,
  }) async {
    final body = jsonEncode({
      'device_id': deviceId,
      'app_name': AppConstants.appName,
      'stars': stars,
      'comment': comment,
    });

    final response = await http
        .post(await _apiUri('add_review'),
            headers: _jsonHeaders, body: body)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Connection timeout'),
        );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  // ── createDeviceWithPlan ──────────────────────────────────────────────

  /// Sends a subscription activation request with plan and contact details.
  ///
  /// [planId] accepts internal values `'half_year'` or `'yearly'`; this method
  /// maps them to the API format (`'6_months'` / `'12_months'`).
  ///
  /// Returns the decoded JSON body on HTTP 200 or 201.
  /// Throws an [Exception] on non-2xx status or network failure.
  Future<Map<String, dynamic>> createDeviceWithPlan({
    required String deviceId,
    required String agentName,
    required String agentPhone,
    required String planId,
    required String contactMethod,
  }) async {
    final requestedPlan = planId == 'yearly' ? '12_months' : '6_months';

    final body = jsonEncode({
      'app_name': AppConstants.appName,
      'device_id': deviceId,
      'full_name': agentName,
      'phone': agentPhone,
      'requested_plan': requestedPlan,
      'contact_method': contactMethod,
      'status': 'pending',
    });

    final response = await http
        .post(await _apiUri(_createDeviceEndpoint),
            headers: _jsonHeaders, body: body)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Connection timeout'),
        );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Server returned status code: ${response.statusCode}');
  }
}


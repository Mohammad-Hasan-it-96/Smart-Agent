import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_plan.dart';

class SubscriptionService {
  static const String _apiUrl = 'https://harrypotter.foodsalebot.com/api/getPlans';

  Future<SubscriptionPlansResponse> fetchPlans() async {
    try {
      final response = await http
          .get(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        
        final success = responseData['success'] == true || responseData['success'] == 1;
        
        if (!success) {
          throw Exception('API returned success: false');
        }

        // Parse currency
        final currencyData = responseData['currency'] as Map<String, dynamic>?;
        final currency = Currency(
          code: currencyData?['code']?.toString() ?? 'USD',
          symbol: currencyData?['symbol']?.toString() ?? '\$',
        );

        // Parse plans
        final plansList = responseData['plans'] as List<dynamic>? ?? [];
        final plans = plansList
            .map((plan) => SubscriptionPlan.fromMap(plan as Map<String, dynamic>))
            .toList();

        return SubscriptionPlansResponse(
          success: true,
          currency: currency,
          plans: plans,
        );
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw with user-friendly message
      throw Exception('تعذر تحميل الباقات، يرجى الاتصال بالإنترنت');
    }
  }
}

class Currency {
  final String code;
  final String symbol;

  Currency({
    required this.code,
    required this.symbol,
  });
}

class SubscriptionPlansResponse {
  final bool success;
  final Currency currency;
  final List<SubscriptionPlan> plans;

  SubscriptionPlansResponse({
    required this.success,
    required this.currency,
    required this.plans,
  });
}

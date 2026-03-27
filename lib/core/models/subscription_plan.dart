class SubscriptionPlan {
  final String id;
  final String title;
  final int durationMonths;
  final double price;
  final double? priceAfterDiscount;
  final bool enabled;
  final bool recommended;
  final String description;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.durationMonths,
    required this.price,
    required this.priceAfterDiscount,
    required this.enabled,
    required this.recommended,
    required this.description,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    double _parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    double? _parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value);
      return null;
    }

    return SubscriptionPlan(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      durationMonths: (map['duration_months'] ?? map['durationMonths'] ?? 0) as int,
      price: _parseDouble(map['price']),
      priceAfterDiscount:
          _parseNullableDouble(map['price_after_discount'] ?? map['priceAfterDiscount']),
      enabled: map['enabled'] == true || map['enabled'] == 1,
      recommended: map['recommended'] == true || map['recommended'] == 1,
      description: map['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'duration_months': durationMonths,
      'price': price,
      'price_after_discount': priceAfterDiscount,
      'enabled': enabled,
      'recommended': recommended,
      'description': description,
    };
  }
}

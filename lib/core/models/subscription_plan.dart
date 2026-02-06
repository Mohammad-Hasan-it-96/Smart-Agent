class SubscriptionPlan {
  final String id;
  final String title;
  final int durationMonths;
  final double price;
  final bool enabled;
  final bool recommended;
  final String description;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.durationMonths,
    required this.price,
    required this.enabled,
    required this.recommended,
    required this.description,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      durationMonths: (map['duration_months'] ?? map['durationMonths'] ?? 0) as int,
      price: (map['price'] ?? 0.0) is int
          ? (map['price'] as int).toDouble()
          : (map['price'] ?? 0.0) as double,
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
      'enabled': enabled,
      'recommended': recommended,
      'description': description,
    };
  }
}

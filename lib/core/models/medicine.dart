class Medicine {
  final int? id;
  final String name;
  final int companyId;
  final double priceUsd;

  Medicine({
    this.id,
    required this.name,
    required this.companyId,
    this.priceUsd = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
      'price_usd': priceUsd,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyId: map['company_id'] as int,
      priceUsd: (map['price_usd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

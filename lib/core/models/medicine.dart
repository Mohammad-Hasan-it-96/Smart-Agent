class Medicine {
  final int? id;
  final String name;
  final int companyId;
  final double priceUsd;
  final String? source;
  final String? form;
  final String? notes;

  Medicine({
    this.id,
    required this.name,
    required this.companyId,
    this.priceUsd = 0.0,
    this.source,
    this.form,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
      'price_usd': priceUsd,
      'source': source,
      'form': form,
      'notes': notes,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyId: map['company_id'] as int,
      priceUsd: (map['price_usd'] as num?)?.toDouble() ?? 0.0,
      source: map['source'] as String?,
      form: map['form'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

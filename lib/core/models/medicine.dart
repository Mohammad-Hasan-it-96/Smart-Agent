class Medicine {
  final int? id;
  final String name;
  final int companyId;

  Medicine({
    this.id,
    required this.name,
    required this.companyId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyId: map['company_id'] as int,
    );
  }
}

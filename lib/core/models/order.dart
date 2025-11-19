class Order {
  final int? id;
  final int pharmacyId;
  final String createdAt;

  Order({
    this.id,
    required this.pharmacyId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pharmacy_id': pharmacyId,
      'created_at': createdAt,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      pharmacyId: map['pharmacy_id'] as int,
      createdAt: map['created_at'] as String,
    );
  }
}

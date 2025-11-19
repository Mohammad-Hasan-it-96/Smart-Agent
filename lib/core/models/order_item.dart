class OrderItem {
  final int? id;
  final int orderId;
  final int medicineId;
  final int qty;

  OrderItem({
    this.id,
    required this.orderId,
    required this.medicineId,
    required this.qty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'medicine_id': medicineId,
      'qty': qty,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      medicineId: map['medicine_id'] as int,
      qty: map['qty'] as int,
    );
  }
}

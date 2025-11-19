class Pharmacy {
  final int? id;
  final String name;
  final String address;
  final String phone;

  Pharmacy({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
    };
  }

  factory Pharmacy.fromMap(Map<String, dynamic> map) {
    return Pharmacy(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
    );
  }
}

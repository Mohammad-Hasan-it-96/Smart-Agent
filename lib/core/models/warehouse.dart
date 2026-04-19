/// A warehouse with a display name and a WhatsApp/phone number.
class Warehouse {
  final String name;
  final String phone;

  const Warehouse({this.name = '', this.phone = ''});

  /// A warehouse is considered valid (filled) when both name and phone are set.
  bool get isFilled => name.trim().isNotEmpty && phone.trim().isNotEmpty;

  /// True when both fields are empty.
  bool get isEmpty => name.trim().isEmpty && phone.trim().isEmpty;

  Map<String, String> toJson() => {'name': name, 'phone': phone};

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
      );

  Warehouse copyWith({String? name, String? phone}) => Warehouse(
        name: name ?? this.name,
        phone: phone ?? this.phone,
      );

  @override
  String toString() => 'Warehouse(name: $name, phone: $phone)';
}


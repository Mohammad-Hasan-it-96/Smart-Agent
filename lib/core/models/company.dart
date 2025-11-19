class Company {
  final int? id;
  final String name;

  Company({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }
}

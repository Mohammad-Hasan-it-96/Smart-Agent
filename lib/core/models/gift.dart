class Gift {
  final int? id;
  final String name;
  final String? notes;

  Gift({this.id, required this.name, this.notes});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'notes': notes};

  factory Gift.fromMap(Map<String, dynamic> map) => Gift(
        id: map['id'] as int?,
        name: map['name'] as String,
        notes: map['notes'] as String?,
      );
}


class EmergencyContact {
  String name;
  String phone;
  String relation;
  int priority;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
    required this.priority,
  });

  // แปลงจาก JSON Map
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      priority: json['priority'] as int? ?? 0,
    );
  }

  // แปลงเป็น JSON Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
      'priority': priority,
    };
  }

  // สร้าง EmergencyContact จาก SharedPreferences
  factory EmergencyContact.fromSharedPreferences(Map<String, dynamic> data) {
    return EmergencyContact(
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      relation: data['relation'] as String? ?? '',
      priority: data['priority'] as int? ?? 0,
    );
  }

  // คัดลอกและอัพเดทค่า
  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relation,
    int? priority,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact(name: $name, phone: $phone, relation: $relation, priority: $priority)';
  }
}

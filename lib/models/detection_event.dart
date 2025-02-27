import 'dart:convert';

class DetectionEvent {
  final String id;
  final String type; // 'fall', 'crash', 'height_change'
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isHandled;

  DetectionEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.data,
    this.isHandled = false,
  });

  // แปลงจาก JSON Map
  factory DetectionEvent.fromJson(Map<String, dynamic> json) {
    return DetectionEvent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>? ?? {},
      isHandled: json['isHandled'] as bool? ?? false,
    );
  }

  // แปลงเป็น JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isHandled': isHandled,
    };
  }

  // สร้าง DetectionEvent จากข้อมูลดิบ
  factory DetectionEvent.fromRawData(Map<String, dynamic> rawData) {
    // ระบุประเภทตามข้อมูลที่มี
    String type = 'unknown';
    if (rawData.containsKey('type')) {
      type = rawData['type'] as String;
    } else if (rawData.containsKey('max_acceleration')) {
      type = 'fall';
    } else if (rawData.containsKey('impact_force')) {
      type = 'crash';
    } else if (rawData.containsKey('height_change')) {
      type = 'height_change';
    }

    // สร้าง ID ที่ไม่ซ้ำกัน
    String id = DateTime.now().millisecondsSinceEpoch.toString();

    // ระบุเวลาที่เกิดเหตุการณ์
    DateTime timestamp;
    if (rawData.containsKey('timestamp')) {
      try {
        timestamp = DateTime.parse(rawData['timestamp'] as String);
      } catch (e) {
        timestamp = DateTime.now();
      }
    } else if (rawData.containsKey('detection_time')) {
      try {
        timestamp = DateTime.parse(rawData['detection_time'] as String);
      } catch (e) {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    return DetectionEvent(
      id: id,
      type: type,
      timestamp: timestamp,
      data: Map<String, dynamic>.from(rawData),
    );
  }

  // คัดลอกและอัพเดทค่า
  DetectionEvent copyWith({
    String? id,
    String? type,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    bool? isHandled,
  }) {
    return DetectionEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      isHandled: isHandled ?? this.isHandled,
    );
  }

  // สำหรับแปลง DetectionEvent เป็น JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // สำหรับสร้าง DetectionEvent จาก JSON string
  factory DetectionEvent.fromJsonString(String jsonString) {
    return DetectionEvent.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }

  // ข้อความสำหรับแสดงผลรายละเอียดของเหตุการณ์
  String getSummary() {
    switch (type) {
      case 'fall':
        return 'ตรวจพบการล้ม (ความเร่ง: ${data['max_acceleration']?.toStringAsFixed(1) ?? '?'} m/s²)';
      case 'crash':
        return 'ตรวจพบการชน (แรงกระแทก: ${data['impact_force']?.toStringAsFixed(1) ?? '?'} G)';
      case 'height_change':
        return 'ตรวจพบการเปลี่ยนความสูง (${data['height_change']?.toStringAsFixed(2) ?? '?'} m)';
      default:
        return 'ตรวจพบเหตุการณ์ที่ไม่ทราบประเภท';
    }
  }

  // ตรวจสอบว่ามีข้อมูลตำแหน่งหรือไม่
  bool hasLocationData() {
    return data.containsKey('location') &&
        data['location'] != null &&
        data['location'] is Map &&
        data['location'].containsKey('latitude') &&
        data['location'].containsKey('longitude');
  }

  // ดึงข้อมูลตำแหน่ง
  Map<String, double>? getLocation() {
    if (!hasLocationData()) return null;

    final location = data['location'] as Map;
    return {
      'latitude': location['latitude'] as double,
      'longitude': location['longitude'] as double,
    };
  }

  @override
  String toString() {
    return 'DetectionEvent(id: $id, type: $type, timestamp: $timestamp, isHandled: $isHandled)';
  }
}

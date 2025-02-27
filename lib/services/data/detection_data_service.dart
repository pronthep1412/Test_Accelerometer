import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../models/detection_event.dart';

/// บริการสำหรับบันทึกและเรียกใช้ข้อมูลการตรวจจับ
class DetectionDataService {
  // ชื่อคีย์ที่ใช้ใน SharedPreferences
  static const String _recentHistoryKey = 'recent_detection_history';
  static const int _maxRecentHistorySize = 20;

  // รายการเหตุการณ์การตรวจจับล่าสุด
  List<DetectionEvent> _recentEvents = [];

  // Singleton pattern
  static final DetectionDataService _instance =
      DetectionDataService._internal();

  factory DetectionDataService() {
    return _instance;
  }

  DetectionDataService._internal();

  /// โหลดประวัติการตรวจจับล่าสุดจาก SharedPreferences
  Future<List<DetectionEvent>> loadRecentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentHistoryKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _recentEvents =
            jsonList.map((json) => DetectionEvent.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading recent history: $e');
      _recentEvents = [];
    }

    return _recentEvents;
  }

  /// บันทึกประวัติการตรวจจับล่าสุดลงใน SharedPreferences
  Future<void> saveRecentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final jsonList = _recentEvents.map((event) => event.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await prefs.setString(_recentHistoryKey, jsonString);
    } catch (e) {
      print('Error saving recent history: $e');
    }
  }

  /// เพิ่มเหตุการณ์ใหม่เข้าไปในประวัติ
  Future<void> addDetectionEvent(Map<String, dynamic> eventData) async {
    // สร้าง DetectionEvent จากข้อมูลดิบ
    final event = DetectionEvent.fromRawData(eventData);

    // เพิ่มเข้าไปในรายการล่าสุด
    _recentEvents.insert(0, event);

    // จำกัดขนาดรายการ
    if (_recentEvents.length > _maxRecentHistorySize) {
      _recentEvents = _recentEvents.sublist(0, _maxRecentHistorySize);
    }

    // บันทึกลงในไฟล์บันทึก
    await _appendToLogFile(event);

    // บันทึกลงใน SharedPreferences
    await saveRecentHistory();
  }

  /// ดึงประวัติการตรวจจับล่าสุด
  List<DetectionEvent> getRecentEvents() {
    return List.unmodifiable(_recentEvents);
  }

  /// ดึงประวัติการตรวจจับล่าสุดโดยประเภท
  List<DetectionEvent> getRecentEventsByType(String type) {
    return _recentEvents.where((event) => event.type == type).toList();
  }

  /// ล้างประวัติการตรวจจับล่าสุด
  Future<void> clearRecentHistory() async {
    _recentEvents.clear();
    await saveRecentHistory();
  }

  /// บันทึกเหตุการณ์ลงในไฟล์บันทึก
  Future<void> _appendToLogFile(DetectionEvent event) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');

      // สร้างโฟลเดอร์ถ้ายังไม่มี
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      // สร้างชื่อไฟล์ตามวันที่
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logFile = File('${logDirectory.path}/detection_log_$dateStr.txt');

      // สร้างข้อความสำหรับบันทึก
      final timeStr = DateFormat('HH:mm:ss').format(event.timestamp);
      String logEntry =
          '[$timeStr] ${event.type.toUpperCase()}: ${event.getSummary()}\n';

      // เพิ่มข้อมูลตำแหน่งถ้ามี
      if (event.hasLocationData()) {
        final location = event.getLocation();
        logEntry +=
            'Location: ${location!['latitude']}, ${location['longitude']}\n';
      }

      // เพิ่มข้อมูลเพิ่มเติม
      logEntry += 'Data: ${jsonEncode(event.data)}\n';
      logEntry += '--------------------\n';

      // เขียนลงไฟล์ (เพิ่มเข้าไป)
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }

  /// บันทึกข้อมูลดิบลงในไฟล์ CSV สำหรับการวิเคราะห์
  Future<void> exportDataToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final csvFile = File('${directory.path}/detection_data_$dateStr.csv');

      // สร้างส่วนหัวของไฟล์ CSV
      String csvContent = 'ID,Type,Timestamp,IsHandled';

      // เพิ่มฟิลด์สำหรับแต่ละประเภท
      csvContent += ',MaxAcceleration,AvgPostImpact,'; // สำหรับการล้ม
      csvContent += 'ImpactForce,Speed,Rotation,'; // สำหรับการชน
      csvContent += 'HeightChange,HeightChangeRate,'; // สำหรับการเปลี่ยนความสูง
      csvContent += 'Latitude,Longitude\n'; // สำหรับตำแหน่ง

      // เพิ่มข้อมูลแต่ละแถว
      for (final event in _recentEvents) {
        // ข้อมูลพื้นฐาน
        csvContent +=
            '${event.id},${event.type},${event.timestamp.toIso8601String()},${event.isHandled},';

        // ข้อมูลการล้ม
        csvContent +=
            '${event.data['max_acceleration'] ?? ''},${event.data['avg_post_impact_acceleration'] ?? ''},';

        // ข้อมูลการชน
        csvContent +=
            '${event.data['impact_force'] ?? ''},${event.data['speed'] ?? ''},${event.data['rotation'] ?? ''},';

        // ข้อมูลการเปลี่ยนความสูง
        csvContent +=
            '${event.data['height_change'] ?? ''},${event.data['height_change_rate'] ?? ''},';

        // ข้อมูลตำแหน่ง
        if (event.hasLocationData()) {
          final location = event.getLocation();
          csvContent += '${location!['latitude']},${location['longitude']}';
        } else {
          csvContent += ',';
        }

        csvContent += '\n';
      }

      // เขียนลงไฟล์
      await csvFile.writeAsString(csvContent);
    } catch (e) {
      print('Error exporting data to CSV: $e');
    }
  }

  /// ดึงขนาดพื้นที่เก็บข้อมูลที่ใช้
  Future<String> getStorageSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');

      if (!await logDirectory.exists()) {
        return '0 KB';
      }

      int totalSize = 0;
      await for (final entity
          in logDirectory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      // แปลงเป็น KB หรือ MB
      if (totalSize < 1024 * 1024) {
        return '${(totalSize / 1024).toStringAsFixed(2)} KB';
      } else {
        return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      print('Error getting storage size: $e');
      return 'ไม่สามารถคำนวณได้';
    }
  }

  /// ล้างข้อมูลบันทึกทั้งหมด
  Future<void> clearAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');

      if (await logDirectory.exists()) {
        await logDirectory.delete(recursive: true);
      }

      // ล้างประวัติล่าสุดด้วย
      await clearRecentHistory();
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
}

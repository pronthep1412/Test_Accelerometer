import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';

class FallDetectionService {
  // ค่าเริ่มต้นที่สำคัญสำหรับการตรวจจับการล้ม
  double _fallThreshold = 20.0; // ความเร่งรวมที่ถือว่าเป็นการล้ม
  double _impactThreshold = 25.0; // ความเร่งสูงสุดที่ถือว่ากระแทกพื้น
  double _stationaryThreshold = 2.0; // ความเร่งต่ำที่ถือว่าอยู่นิ่ง

  bool _isMonitoring = false;
  bool _isPossibleFall = false;
  DateTime? _fallStartTime;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Callbacks
  final Function(Map<String, dynamic>)? onFallDetected;
  final VoidCallback? onFalseAlarm;

  // สำหรับเก็บข้อมูลความเร่งเพื่อวิเคราะห์
  List<double> _accelerationMagnitudes = [];
  Timer? _analysisTimer;

  // ข้อมูลความเร่งล่าสุด
  double _lastAcceleration = 0.0;

  FallDetectionService({this.onFallDetected, this.onFalseAlarm});

  bool get isMonitoring => _isMonitoring;
  double get lastAcceleration => _lastAcceleration;

  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _accelerationMagnitudes = [];

    // เริ่มอ่านข้อมูลจาก accelerometer
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });

    // ตั้งเวลาวิเคราะห์ข้อมูลทุก 50ms
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _analyzeAccelerationData();
    });

    print("Fall detection monitoring started");
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelerometerSubscription?.cancel();
    _analysisTimer?.cancel();
    print("Fall detection monitoring stopped");
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // คำนวณความเร่งรวม (magnitude) จากแกน x, y, z
    double magnitude =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // หักแรงโน้มถ่วงโลก (ประมาณ 9.8 m/s²)
    magnitude = (magnitude - 9.8).abs();
    _lastAcceleration = magnitude;

    // เก็บข้อมูลสำหรับวิเคราะห์
    _accelerationMagnitudes.add(magnitude);

    // เก็บเฉพาะข้อมูลล่าสุด 20 ค่า (ประมาณ 1 วินาที ถ้าอ่านที่ 20Hz)
    if (_accelerationMagnitudes.length > 20) {
      _accelerationMagnitudes.removeAt(0);
    }
  }

  void _analyzeAccelerationData() {
    if (_accelerationMagnitudes.length < 10) {
      return; // ต้องมีข้อมูลพอสำหรับวิเคราะห์
    }

    // หาค่า max และ min ในช่วงเวลาที่ผ่านมา
    double maxAcceleration = _accelerationMagnitudes.reduce(max);

    // Algorithm สำหรับตรวจจับการล้ม:
    // 1. ตรวจสอบการเปลี่ยนแปลงความเร่งอย่างฉับพลัน (การล้ม)
    if (!_isPossibleFall && maxAcceleration > _fallThreshold) {
      _isPossibleFall = true;
      _fallStartTime = DateTime.now();
      print("Possible fall detected: $maxAcceleration");
    }

    // 2. ถ้ากำลังตรวจสอบการล้มที่อาจเกิดขึ้น
    if (_isPossibleFall && _fallStartTime != null) {
      int elapsedTimeMs =
          DateTime.now().difference(_fallStartTime!).inMilliseconds;

      // 3. ตรวจสอบถ้ามีการกระแทก (impact) และตามด้วยความเร่งต่ำ (นิ่ง) ในช่วงเวลาที่เหมาะสม
      if (elapsedTimeMs > 300 && elapsedTimeMs < 2000) {
        // ตรวจหา impact ที่พื้น
        if (maxAcceleration > _impactThreshold) {
          // ตรวจสอบว่าหลังจากกระแทกแล้วไม่มีการเคลื่อนไหว
          List<double> recentValues =
              _accelerationMagnitudes.reversed.take(5).toList();
          double avgRecentAcceleration =
              recentValues.reduce((a, b) => a + b) / recentValues.length;

          if (avgRecentAcceleration < _stationaryThreshold) {
            // ส่งสัญญาณว่าตรวจพบการล้ม
            _handleFallDetection(maxAcceleration, avgRecentAcceleration);
          }
        }
      } else if (elapsedTimeMs >= 2000) {
        // รีเซ็ตการตรวจสอบหลังจาก 2 วินาที
        _isPossibleFall = false;
      }
    }
  }

  void _handleFallDetection(
      double maxAcceleration, double avgRecentAcceleration) {
    print("FALL DETECTED! Max acceleration: $maxAcceleration");
    _isPossibleFall = false;

    // สั่นเตือน
    Vibration.vibrate(duration: 1000);

    // รวบรวมข้อมูลการตรวจจับ
    Map<String, dynamic> fallData = {
      'timestamp': DateTime.now().toIso8601String(),
      'max_acceleration': maxAcceleration,
      'avg_post_impact_acceleration': avgRecentAcceleration,
      'type': 'fall',
    };

    // เรียกฟังก์ชันที่ส่งมาจากข้างนอก
    onFallDetected?.call(fallData);
  }

  void cancelFallAlert() {
    // เรียกเมื่อผู้ใช้ยกเลิกการแจ้งเตือน
    onFalseAlarm?.call();
  }

  // บันทึกการตั้งค่าความไวของการตรวจจับ
  Future<void> setSensitivity(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fall_detection_sensitivity', level);

    // ปรับค่า threshold ตามระดับความไว
    switch (level) {
      case 'high':
        // ไวมาก - ตรวจจับง่าย แต่อาจมี false positive
        _fallThreshold = 15.0;
        _impactThreshold = 20.0;
        _stationaryThreshold = 3.0;
        break;
      case 'medium':
        // ค่ากลาง - เป็นค่าเริ่มต้น
        _fallThreshold = 20.0;
        _impactThreshold = 25.0;
        _stationaryThreshold = 2.0;
        break;
      case 'low':
        // ไวน้อย - ต้องล้มรุนแรงถึงจะตรวจจับได้
        _fallThreshold = 25.0;
        _impactThreshold = 30.0;
        _stationaryThreshold = 1.5;
        break;
    }
  }

  // โหลดการตั้งค่าความไว
  Future<void> loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    String level = prefs.getString('fall_detection_sensitivity') ?? 'medium';
    await setSensitivity(level);
  }
}

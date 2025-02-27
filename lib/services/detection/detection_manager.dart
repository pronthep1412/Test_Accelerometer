import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'fall_detection_service.dart';
import 'crash_detection_service.dart';
import 'motion_detection_service.dart';

/// DetectionManager - จัดการและประสานงานบริการตรวจจับทั้งหมด
class DetectionManager {
  // Services
  late FallDetectionService _fallDetectionService;
  late CrashDetectionService _crashDetectionService;
  late MotionDetectionService _motionDetectionService;

  // การตั้งค่าการทำงาน
  bool _motionBasedDetection = false;

  // สถานะการทำงาน
  bool _fallDetectionEnabled = false;
  bool _crashDetectionEnabled = false;

  // Callbacks
  Function(Map<String, dynamic>)? onDetectionEvent;
  VoidCallback? onFalseAlarm;

  // สำหรับเก็บประวัติการตรวจจับล่าสุด
  final List<Map<String, dynamic>> _recentDetectionHistory = [];
  static const int MAX_HISTORY_SIZE = 20;

  // Singleton pattern
  static final DetectionManager _instance = DetectionManager._internal();

  factory DetectionManager({
    Function(Map<String, dynamic>)? onDetectionEvent,
    VoidCallback? onFalseAlarm,
  }) {
    _instance.onDetectionEvent = onDetectionEvent;
    _instance.onFalseAlarm = onFalseAlarm;
    return _instance;
  }

  DetectionManager._internal() {
    _initializeServices();
  }

  // เริ่มต้นบริการ
  void _initializeServices() {
    // สร้างบริการตรวจจับการล้ม
    _fallDetectionService = FallDetectionService(
      onFallDetected: _handleFallDetection,
      onFalseAlarm: _handleFalseAlarm,
    );

    // สร้างบริการตรวจจับการชน
    _crashDetectionService = CrashDetectionService(
      onCrashDetected: _handleCrashDetection,
      onFalseAlarm: _handleFalseAlarm,
    );

    // สร้างบริการตรวจจับการเคลื่อนไหว
    _motionDetectionService = MotionDetectionService(
      onMotionStateChanged: _handleMotionStateChange,
    );
  }

  // โหลดการตั้งค่า
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _motionBasedDetection = prefs.getBool('motion_based_detection') ?? false;
    _fallDetectionEnabled = prefs.getBool('fall_detection_enabled') ?? false;
    _crashDetectionEnabled = prefs.getBool('crash_detection_enabled') ?? false;

    // โหลดการตั้งค่าความไวสำหรับบริการต่างๆ
    await _fallDetectionService.loadSensitivity();
    await _crashDetectionService.loadSensitivity();
    await _motionDetectionService.loadSensitivity();
  }

  // บันทึกการตั้งค่า
  Future<void> saveSettings({
    bool? motionBased,
    bool? fallEnabled,
    bool? crashEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (motionBased != null) {
      _motionBasedDetection = motionBased;
      await prefs.setBool('motion_based_detection', motionBased);
    }

    if (fallEnabled != null) {
      _fallDetectionEnabled = fallEnabled;
      await prefs.setBool('fall_detection_enabled', fallEnabled);
    }

    if (crashEnabled != null) {
      _crashDetectionEnabled = crashEnabled;
      await prefs.setBool('crash_detection_enabled', crashEnabled);
    }
  }

  // เริ่มการตรวจจับทั้งหมด
  Future<void> startDetection() async {
    await loadSettings();

    if (_motionBasedDetection) {
      // เริ่มเฉพาะการตรวจจับการเคลื่อนไหว บริการอื่นๆ จะเริ่มเมื่อตรวจพบการเคลื่อนไหว
      _motionDetectionService.startMonitoring();
    } else {
      // เริ่มบริการตามการตั้งค่า
      _startDetectionServices();
    }

    print("Detection manager started");
  }

  // หยุดการตรวจจับทั้งหมด
  void stopDetection() {
    _motionDetectionService.stopMonitoring();
    _fallDetectionService.stopMonitoring();
    _crashDetectionService.stopMonitoring();

    print("Detection manager stopped");
  }

  // เริ่มบริการตรวจจับตามการตั้งค่า
  void _startDetectionServices() {
    if (_fallDetectionEnabled) {
      _fallDetectionService.startMonitoring();
    }

    if (_crashDetectionEnabled) {
      _crashDetectionService.startMonitoring();
    }
  }

  // จัดการเมื่อสถานะการเคลื่อนไหวเปลี่ยน
  void _handleMotionStateChange(bool isActive) {
    if (_motionBasedDetection) {
      if (isActive) {
        // เริ่มการตรวจจับเมื่อมีการเคลื่อนไหว
        _startDetectionServices();
        print("Motion detected: Starting detection services");
      } else {
        // หยุดการตรวจจับเมื่อไม่มีการเคลื่อนไหว
        _fallDetectionService.stopMonitoring();
        _crashDetectionService.stopMonitoring();
        print("No motion: Stopping detection services");
      }
    }
  }

  // จัดการเมื่อตรวจพบการล้ม
  void _handleFallDetection(Map<String, dynamic> fallData) {
    // เพิ่มข้อมูลเพิ่มเติม
    fallData['detection_time'] = DateTime.now().toIso8601String();

    // บันทึกประวัติ
    _addToDetectionHistory(fallData);

    // ส่งข้อมูลไปยัง callback
    onDetectionEvent?.call(fallData);
  }

  // จัดการเมื่อตรวจพบการชน
  void _handleCrashDetection(Map<String, dynamic> crashData) {
    // เพิ่มข้อมูลเพิ่มเติม
    crashData['detection_time'] = DateTime.now().toIso8601String();

    // บันทึกประวัติ
    _addToDetectionHistory(crashData);

    // ส่งข้อมูลไปยัง callback
    onDetectionEvent?.call(crashData);
  }

  // จัดการเมื่อมีการยกเลิกการแจ้งเตือน
  void _handleFalseAlarm() {
    onFalseAlarm?.call();
  }

  // เพิ่มข้อมูลไปยังประวัติการตรวจจับ
  void _addToDetectionHistory(Map<String, dynamic> detectionData) {
    _recentDetectionHistory.add(detectionData);

    // จำกัดขนาดประวัติ
    if (_recentDetectionHistory.length > MAX_HISTORY_SIZE) {
      _recentDetectionHistory.removeAt(0);
    }
  }

  // ดึงข้อมูลประวัติการตรวจจับล่าสุด
  List<Map<String, dynamic>> getRecentDetectionHistory() {
    return List.from(_recentDetectionHistory.reversed);
  }

  // ดึงข้อมูลล่าสุดจากแต่ละบริการ
  Map<String, dynamic> getCurrentSensorData() {
    return {
      'acceleration': _fallDetectionService.lastAcceleration,
      'motion_active': _motionDetectionService.isActive,
      'crash_speed': _crashDetectionService.lastSpeed,
      'crash_rotation': _crashDetectionService.lastRotation,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Getters สำหรับสถานะการทำงาน
  bool get isFallDetectionEnabled => _fallDetectionEnabled;
  bool get isCrashDetectionEnabled => _crashDetectionEnabled;
  bool get isMotionBasedDetectionEnabled => _motionBasedDetection;

  bool get isAnyDetectionActive {
    return _motionDetectionService.isMonitoring ||
        _fallDetectionService.isMonitoring ||
        _crashDetectionService.isMonitoring;
  }

  // Setters สำหรับการตั้งค่าความไวของแต่ละบริการ
  Future<void> setFallDetectionSensitivity(String level) async {
    await _fallDetectionService.setSensitivity(level);
  }

  Future<void> setCrashDetectionSensitivity(String level) async {
    await _crashDetectionService.setSensitivity(level);
  }

  Future<void> setMotionDetectionSensitivity(String level) async {
    await _motionDetectionService.setSensitivity(level);
  }


  // เปิด/ปิดการตรวจจับการล้ม
  Future<void> toggleFallDetection(bool enabled) async {
    await saveSettings(fallEnabled: enabled);

    if (enabled && !_motionBasedDetection) {
      _fallDetectionService.startMonitoring();

    } else if (!enabled) {
      _fallDetectionService.stopMonitoring();

    }
  }

  // เปิด/ปิดการตรวจจับการชน
  Future<void> toggleCrashDetection(bool enabled) async {
    await saveSettings(crashEnabled: enabled);

    if (enabled && !_motionBasedDetection) {
      _crashDetectionService.startMonitoring();
    } else if (!enabled) {
      _crashDetectionService.stopMonitoring();
    }
  }

  // เปิด/ปิดการตรวจจับตามการเคลื่อนไหว
  Future<void> toggleMotionBasedDetection(bool enabled) async {
    await saveSettings(motionBased: enabled);

    if (enabled) {
      // หยุดบริการทั้งหมดก่อน
      _fallDetectionService.stopMonitoring();
      _crashDetectionService.stopMonitoring();

      // เริ่มเฉพาะ motion detection
      _motionDetectionService.startMonitoring();
    } else {
      // เริ่มบริการตามการตั้งค่า
      _startDetectionServices();
    }
  }

}

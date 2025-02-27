import 'dart:async';
import 'package:app_accelerometer/services/background/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../detection/detection_manager.dart';
import 'background_service.dart';

/// จัดการการสื่อสารกับโค้ด native บน iOS สำหรับการทำงานเบื้องหลัง
class IOSBackgroundChannel {
  // ช่องทางการสื่อสารกับ native code
  static const MethodChannel _channel =
      MethodChannel('com.example.appAccelerometer/channel');

  // บริการที่เกี่ยวข้อง
  static final BackgroundService _backgroundService = BackgroundService();
  static final DetectionManager _detectionManager = DetectionManager();

  // สถานะ
  static bool _isInitialized = false;

  /// เริ่มต้นการทำงานของ channel
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // กำหนด method handler
    _channel.setMethodCallHandler(_handleMethodCall);

    // ตรวจสอบว่าควรเริ่มบริการโดยอัตโนมัติหรือไม่
    final prefs = await SharedPreferences.getInstance();
    bool autoStart = prefs.getBool('auto_start_on_boot') ?? false;

    if (autoStart) {
      // เรียกเมธอดไปยัง native code เพื่อลงทะเบียนเริ่มอัตโนมัติ
      try {
        await _channel.invokeMethod('registerAutoStart');
      } catch (e) {
        print('Error registering iOS auto start: $e');
      }

      // เริ่มบริการตรวจจับ
      await _backgroundService.startBackgroundService();
    }

    _isInitialized = true;
  }

  /// จัดการ method call จาก native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'startBackgroundService':
        await _backgroundService.startBackgroundService();
        return true;

      case 'stopBackgroundService':
        await _backgroundService.stopBackgroundService();
        return true;

      case 'onBackgroundFetch':
        return _handleBackgroundFetch();

      case 'onBackgroundProcessing':
        return _handleBackgroundProcessing();

      case 'onAppWillTerminate':
        return _handleAppTermination();

      case 'testNotification':
        final notificationService = NotificationService();
        await notificationService.initialize();
        return await notificationService.testNotification();
        
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  /// จัดการกับ background fetch
  static Future<bool> _handleBackgroundFetch() async {
    print('iOS background fetch started');

    final prefs = await SharedPreferences.getInstance();
    final bool fallDetectionEnabled =
        prefs.getBool('fall_detection_enabled') ?? false;
    final bool crashDetectionEnabled =
        prefs.getBool('crash_detection_enabled') ?? false;

    if (fallDetectionEnabled || crashDetectionEnabled) {
      // ตรวจสอบว่ากำลังตรวจจับอยู่หรือไม่
      final bool isActive = _detectionManager.isAnyDetectionActive;

      if (!isActive) {
        // เริ่มการตรวจจับใหม่
        await _detectionManager.startDetection();
      }

      // ต้องคืนค่า true เพื่อบอก iOS ว่ามีข้อมูลใหม่
      return true;
    }

    return false;
  }

  /// จัดการกับ background processing
  static Future<bool> _handleBackgroundProcessing() async {
    print('iOS background processing started');

    // ตรวจสอบว่าควรทำงานในเบื้องหลังหรือไม่
    final prefs = await SharedPreferences.getInstance();
    final bool runInBackground = prefs.getBool('run_in_background') ?? true;

    if (!runInBackground) {
      _detectionManager.stopDetection();
      return false;
    }

    final bool fallDetectionEnabled =
        prefs.getBool('fall_detection_enabled') ?? false;
    final bool crashDetectionEnabled =
        prefs.getBool('crash_detection_enabled') ?? false;

    if (fallDetectionEnabled || crashDetectionEnabled) {
      // เริ่มการตรวจจับ
      await _detectionManager.startDetection();
      return true;
    }

    return false;
  }

  /// จัดการกับการปิดแอป
  static Future<void> _handleAppTermination() async {
    // บันทึกสถานะการทำงานก่อนปิดแอป
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('was_running_before_termination',
        _detectionManager.isAnyDetectionActive);

    // หยุดการตรวจจับ (เพื่อปิดทรัพยากรอย่างเหมาะสม)
    _detectionManager.stopDetection();
  }

  /// ตั้งค่าการเริ่มอัตโนมัติ
  static Future<void> setAutoStartOnBoot(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_start_on_boot', enabled);

    if (enabled) {
      // ลงทะเบียนสำหรับการเริ่มอัตโนมัติ
      try {
        await _channel.invokeMethod('registerAutoStart');
      } catch (e) {
        print('Error registering iOS auto start: $e');
      }
    } else {
      // ยกเลิกการลงทะเบียนสำหรับการเริ่มอัตโนมัติ
      try {
        await _channel.invokeMethod('unregisterAutoStart');
      } catch (e) {
        print('Error unregistering iOS auto start: $e');
      }
    }
  }

  /// เริ่มการตรวจจับอีกครั้งหลังจากแอปกลับมาทำงาน
  static Future<void> resumeDetectionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool wasRunning =
        prefs.getBool('was_running_before_termination') ?? false;

    if (wasRunning) {
      await _detectionManager.startDetection();
    }
  }

  /// กำหนดค่า Background Fetch
  static Future<void> configureBackgroundFetch() async {
    try {
      await _channel.invokeMethod('configureBackgroundFetch');
    } catch (e) {
      print('Error configuring background fetch: $e');
    }
  }

  /// กำหนดค่า Background Processing
  static Future<void> configureBackgroundProcessing() async {
    try {
      await _channel.invokeMethod('configureBackgroundProcessing');
    } catch (e) {
      print('Error configuring background processing: $e');
    }
  }

  /// กำหนดระยะเวลาสำหรับ Background Fetch
  static Future<void> setBackgroundFetchInterval(int seconds) async {
    try {
      await _channel.invokeMethod('setBackgroundFetchInterval', {
        'seconds': seconds,
      });
    } catch (e) {
      print('Error setting background fetch interval: $e');
    }
  }

  /// ตรวจสอบสถานะการลงทะเบียนสำหรับการเริ่มอัตโนมัติ
  static Future<bool> isRegisteredForAutoStart() async {
    try {
      return await _channel.invokeMethod('isRegisteredForAutoStart') ?? false;
    } catch (e) {
      print('Error checking auto start registration: $e');
      return false;
    }
  }
}

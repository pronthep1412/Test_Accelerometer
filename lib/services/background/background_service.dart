import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../detection/detection_manager.dart';
import '../data/detection_data_service.dart';
import '../data/settings_service.dart';
import 'notification_service.dart';

/// บริการสำหรับการทำงานในโหมดเบื้องหลัง
class BackgroundService {
  static const String BACKGROUND_SERVICE_PORT_NAME =
      'fall_crash_detection_port';
  static const int NOTIFICATION_ID = 888;

  // บริการตรวจจับ
  late DetectionManager _detectionManager;

  // บริการข้อมูล
  late DetectionDataService _detectionDataService;
  late SettingsService _settingsService;

  // บริการแจ้งเตือน
  late NotificationService _notificationService;

  // สำหรับ background service
  late FlutterBackgroundService _backgroundService;

  // สถานะการทำงาน
  bool _isRunningInBackground = false;

  // Isolate communication
  ReceivePort? _receivePort;
  SendPort? _uiSendPort;

  // Singleton pattern
  static final BackgroundService _instance = BackgroundService._internal();

  factory BackgroundService() {
    return _instance;
  }

  BackgroundService._internal() {
    _initServices();
  }

  void _initServices() {
    // สร้างบริการต่างๆ
    _detectionManager = DetectionManager();
    _detectionDataService = DetectionDataService();
    _settingsService = SettingsService();
    _notificationService = NotificationService();
    _backgroundService = FlutterBackgroundService();
  }

  /// เริ่มต้นบริการเบื้องหลัง
  Future<void> initialize() async {
    await _notificationService.initialize();

    // ตั้งค่าบริการเบื้องหลัง
    await _configureBackgroundService();

    // ตั้งค่าการสื่อสารระหว่าง isolate
    _setupBackgroundChannel();
  }

  /// ตั้งค่าบริการเบื้องหลัง
  Future<void> _configureBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'fall_crash_detection_channel',
        initialNotificationTitle: 'ระบบตรวจจับการล้มและการชน',
        initialNotificationContent: 'กำลังทำงานในโหมดเบื้องหลัง',
        foregroundServiceNotificationId: NOTIFICATION_ID,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBackgroundStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// callback ที่จะทำงานในโหมดเบื้องหลังบน Android
  @pragma('vm:entry-point')
  static void _onBackgroundStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // เริ่มต้น services
    final detectionManager = DetectionManager();
    final detectionDataService = DetectionDataService();
    final settingsService = SettingsService();

    // โหลดการตั้งค่า
    await settingsService.loadSettings();
    final settings = settingsService.settings;

    // สำหรับการสื่อสารกับ UI
    final receivePort = ReceivePort();
    const String portName = BACKGROUND_SERVICE_PORT_NAME + '_service';

    if (IsolateNameServer.lookupPortByName(portName) != null) {
      IsolateNameServer.removePortNameMapping(portName);
    }

    IsolateNameServer.registerPortWithName(receivePort.sendPort, portName);

    // รับข้อความจาก UI
    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        final type = message['type'] as String?;

        switch (type) {
          case 'stop':
            service.stopSelf();
            break;
          case 'update_settings':
            // อัพเดทการตั้งค่า
            break;
        }
      }
    });

    // สำหรับ Android
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // สำหรับทั้ง Android และ iOS
    service.on('stopService').listen((event) {
      detectionManager.stopDetection();
      service.stopSelf();
    });

    // เริ่มการตรวจจับ
    if (settings.fallDetectionEnabled || settings.crashDetectionEnabled) {
      // ตั้งค่า callback สำหรับเมื่อตรวจพบ
      detectionManager.onDetectionEvent = (eventData) async {
        // บันทึกข้อมูล
        await detectionDataService.addDetectionEvent(eventData);

        // ส่งข้อมูลไปยัง UI ถ้าเปิดอยู่
        final uiPort =
            IsolateNameServer.lookupPortByName(BACKGROUND_SERVICE_PORT_NAME);
        if (uiPort != null) {
          uiPort.send({
            'type': 'detection_event',
            'data': eventData,
          });
        }

        // แจ้งเตือน (จะขึ้นกับ notification service ที่ต้องสร้างเพิ่ม)
        // ...
      };

      // เริ่มการตรวจจับตามการตั้งค่า
      await detectionManager.startDetection();
    }

    // อัพเดทสถานะทุก 1 นาที
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // อัพเดทข้อความการแจ้งเตือน
          service.setForegroundNotificationInfo(
            title: 'ระบบตรวจจับการล้มและการชน',
            content:
                'กำลังทำงานในโหมดเบื้องหลัง (${DateTime.now().hour}:${DateTime.now().minute})',
          );
        }
      }

      // ทดสอบส่งการแจ้งเตือนทุก 5 นาที
      if (timer.tick % 1 == 0) {
        final notificationService = NotificationService();
        await notificationService.initialize();
        final success = await notificationService.testNotification();
        print(
            'BackgroundService: ทดสอบการแจ้งเตือนในรอบที่ ${timer.tick} - ${success ? "สำเร็จ" : "ล้มเหลว"}');
      }

      // ส่งข้อมูลไปยัง UI
      final uiPort =
          IsolateNameServer.lookupPortByName(BACKGROUND_SERVICE_PORT_NAME);
      if (uiPort != null) {
        uiPort.send({
          'type': 'status_update',
          'data': {
            'timestamp': DateTime.now().toIso8601String(),
            'is_monitoring': detectionManager.isAnyDetectionActive,
          },
        });
      }

      // บันทึกสถานะการทำงาน
      service.invoke('update', {
        'timestamp': DateTime.now().toIso8601String(),
        'is_monitoring': detectionManager.isAnyDetectionActive,
      });
    });
  }

  /// callback สำหรับ iOS เมื่อแอพทำงานในเบื้องหลัง
  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    print('iOS background task started');

    // คืนค่า true เพื่อให้ระบบรู้ว่างานเบื้องหลังควรทำงานต่อ
    return true;
  }

  /// ตั้งค่าช่องทางการสื่อสารระหว่าง isolate
  void _setupBackgroundChannel() {
    _receivePort ??= ReceivePort();

    // ลงทะเบียนพอร์ทสำหรับการติดต่อ
    if (IsolateNameServer.lookupPortByName(BACKGROUND_SERVICE_PORT_NAME) !=
        null) {
      IsolateNameServer.removePortNameMapping(BACKGROUND_SERVICE_PORT_NAME);
    }

    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      BACKGROUND_SERVICE_PORT_NAME,
    );

    // ตั้งค่า callback สำหรับรับข้อความ
    _receivePort!.listen((message) {
      if (message is Map<String, dynamic>) {
        _handleMessageFromBackground(message);
      }
    });
  }

  /// จัดการข้อความจากโปรเซสเบื้องหลัง
  void _handleMessageFromBackground(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'detection_event':
        final eventData = message['data'] as Map<String, dynamic>;
        _handleDetectionEvent(eventData);
        break;

      case 'status_update':
        // อัพเดทสถานะ UI
        break;
    }
  }

  /// จัดการเมื่อได้รับเหตุการณ์การตรวจจับจากโปรเซสเบื้องหลัง
  void _handleDetectionEvent(Map<String, dynamic> eventData) {
    // บันทึกข้อมูล
    _detectionDataService.addDetectionEvent(eventData);

    // สร้างการแจ้งเตือน
    final eventType = eventData['type'] as String?;

    if (eventType == 'fall') {
      _notificationService.showFallDetectionNotification(eventData);
    } else if (eventType == 'crash') {
      _notificationService.showCrashDetectionNotification(eventData);
    }
  }

  /// เริ่มการทำงานในโหมดเบื้องหลัง
  Future<bool> startBackgroundService() async {
    if (_isRunningInBackground) return true;

    try {
      // โหลดการตั้งค่า
      await _settingsService.loadSettings();

      // ตรวจสอบว่ามีการตั้งค่าให้เปิดใช้งานการตรวจจับหรือไม่
      if (!_settingsService.settings.fallDetectionEnabled &&
          !_settingsService.settings.crashDetectionEnabled) {
        return false;
      }

      // เริ่มบริการเบื้องหลัง
      await _backgroundService.startService();

      _isRunningInBackground = true;
      return true;
    } catch (e) {
      print("Error starting background service: $e");
      return false;
    }
  }

  /// หยุดการทำงานในโหมดเบื้องหลัง
  Future<void> stopBackgroundService() async {
    if (!_isRunningInBackground) return;

    // ส่งคำสั่งหยุดไปยังบริการเบื้องหลัง
    _backgroundService.invoke('stopService');

    _isRunningInBackground = false;
    print("Background service stopped");
  }

  /// ส่งข้อความไปยังโปรเซสเบื้องหลัง
  Future<void> sendMessageToBackground(Map<String, dynamic> message) async {
    _backgroundService.invoke('update', message);
  }

  /// อัพเดทการตั้งค่าในโปรเซสเบื้องหลัง
  Future<void> updateBackgroundSettings() async {
    _backgroundService.invoke(
        'update_settings', _settingsService.settings.toJson());
  }

  /// ตรวจสอบว่าบริการเบื้องหลังกำลังทำงานหรือไม่
  Future<bool> isServiceRunning() async {
    return await _backgroundService.isRunning();
  }

  /// ทำความสะอาดเมื่อไม่ได้ใช้งาน
  void dispose() {
    stopBackgroundService();

    if (_receivePort != null) {
      IsolateNameServer.removePortNameMapping(BACKGROUND_SERVICE_PORT_NAME);
      _receivePort!.close();
      _receivePort = null;
    }
  }

  // Getters
  bool get isRunningInBackground => _isRunningInBackground;
}

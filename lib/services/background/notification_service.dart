import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/emergency_contacts_service.dart';

/// ข้อมูลเมื่อผู้ใช้แตะการแจ้งเตือน
class NotificationAction {
  final String id;
  final String type;
  final Map<String, dynamic>? payload;

  NotificationAction({
    required this.id,
    required this.type,
    this.payload,
  });

  @override
  String toString() =>
      'NotificationAction(id: $id, type: $type, payload: $payload)';
}

/// บริการสำหรับการแจ้งเตือนการตรวจจับ
class NotificationService {
  // สำหรับแสดงการแจ้งเตือน
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // สำหรับจัดการผู้ติดต่อฉุกเฉิน
  final EmergencyContactsService _contactsService = EmergencyContactsService();

  // รายการ ID ของการแจ้งเตือน
  static const int FOREGROUND_NOTIFICATION_ID = 888;
  static const int FALL_NOTIFICATION_ID = 889;
  static const int CRASH_NOTIFICATION_ID = 890;
  static const int REMINDER_NOTIFICATION_ID = 891;

  // ชื่อช่องการแจ้งเตือน
  static const String FOREGROUND_CHANNEL_ID = 'fall_crash_detection_channel';
  static const String EMERGENCY_CHANNEL_ID = 'emergency_alerts_channel';
  static const String REMINDER_CHANNEL_ID = 'reminders_channel';

  // Callback เมื่อมีการแตะการแจ้งเตือน
  Function(NotificationAction)? onNotificationTap;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// เริ่มต้นบริการการแจ้งเตือน
  Future<void> initialize() async {
    // ตั้งค่าการแจ้งเตือนสำหรับ Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ตั้งค่าการแจ้งเตือนสำหรับ iOS
    final iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    // รวมการตั้งค่าสำหรับทุกแพลตฟอร์ม
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    // เริ่มต้นปลั๊กอิน
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // สร้างช่องการแจ้งเตือนสำหรับ Android
    await _createNotificationChannels();

    // ขอสิทธิ์การแจ้งเตือนสำหรับ iOS
    await _requestIOSPermissions();
  }

  /// ทดสอบส่งการแจ้งเตือนและคืนค่าว่าสำเร็จหรือไม่
  Future<bool> testNotification() async {
    try {
      // สร้างการแจ้งเตือนทดสอบแบบง่าย
      const androidDetails = AndroidNotificationDetails(
        REMINDER_CHANNEL_ID,
        'การแจ้งเตือนทดสอบ',
        channelDescription: 'ทดสอบระบบแจ้งเตือน',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // ID ไม่ซ้ำกัน
      final id = DateTime.now().millisecondsSinceEpoch % 10000;

      // ส่งการแจ้งเตือน
      await _notificationsPlugin.show(
        id,
        'ทดสอบการแจ้งเตือน',
        'หากคุณเห็นข้อความนี้ แสดงว่าการแจ้งเตือนทำงานได้',
        notificationDetails,
      );

      // บันทึกล็อก
      print('NotificationService: ส่งการแจ้งเตือนทดสอบสำเร็จ ID=$id');
      return true;
    } catch (e) {
      // บันทึกข้อผิดพลาด
      print('NotificationService: เกิดข้อผิดพลาดในการส่งการแจ้งเตือน: $e');
      return false;
    }
  }

  /// สร้างช่องการแจ้งเตือนสำหรับ Android
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Define channels
        const foregroundChannel = AndroidNotificationChannel(
          FOREGROUND_CHANNEL_ID,
          'การทำงานเบื้องหลัง',
          description: 'แสดงเมื่อแอปกำลังทำงานในโหมดเบื้องหลัง',
          importance: Importance.low,
        );

        const emergencyChannel = AndroidNotificationChannel(
          EMERGENCY_CHANNEL_ID,
          'การแจ้งเตือนฉุกเฉิน',
          description: 'แสดงเมื่อตรวจพบการล้มหรือการชน',
          importance: Importance.high,
        );

        const reminderChannel = AndroidNotificationChannel(
          REMINDER_CHANNEL_ID,
          'การแจ้งเตือนทั่วไป',
          description: 'แสดงการแจ้งเตือนทั่วไปของแอป',
          importance: Importance.defaultImportance,
        );

        // Create notification channels one by one
        await androidPlugin.createNotificationChannel(foregroundChannel);
        await androidPlugin.createNotificationChannel(emergencyChannel);
        await androidPlugin.createNotificationChannel(reminderChannel);
      }
    }
  }

  /// ขอสิทธิ์การแจ้งเตือนสำหรับ iOS
  Future<void> _requestIOSPermissions() async {
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true, // เพิ่มสิทธิ์การแจ้งเตือนแบบสำคัญ
          );
    }
  }

  /// ขอสิทธิ์การแจ้งเตือนฉุกเฉิน (Critical Alerts) สำหรับ iOS
  Future<bool> requestCriticalAlertsPermission() async {
    if (Platform.isIOS) {
      final plugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (plugin != null) {
        return await plugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            ) ??
            false;
      }
    }
    return false;
  }

  /// จัดการเมื่อผู้ใช้ตอบสนองต่อการแจ้งเตือน
  void _onNotificationResponse(NotificationResponse response) {
    // แปลงข้อมูล payload เป็น Map (ถ้ามี)
    Map<String, dynamic>? payload;
    if (response.payload != null) {
      try {
        // ลองแปลงเป็น JSON ก่อน
        payload = json.decode(response.payload!) as Map<String, dynamic>;
      } catch (e) {
        // ถ้าไม่ใช่ JSON ให้เก็บเป็นข้อความปกติ
        payload = {'data': response.payload};
        print('Error parsing notification payload: $e');
      }
    }

    // สร้างข้อมูลการกระทำ
    final action = NotificationAction(
      id: response.id.toString(),
      type: response.notificationResponseType.name,
      payload: payload,
    );

    // เรียก callback ถ้ามีการกำหนดไว้
    onNotificationTap?.call(action);
  }

  /// แสดงการแจ้งเตือนเมื่อตรวจพบการล้ม
  Future<void> showFallDetectionNotification(
      Map<String, dynamic> fallData) async {
    final prefs = await SharedPreferences.getInstance();
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    // ดึงข้อมูลผู้ติดต่อฉุกเฉิน
    final contact = await _contactsService.getPrimaryContact();
    String contactInfo = '';
    if (contact != null && contact.name.isNotEmpty) {
      contactInfo = '\nผู้ติดต่อฉุกเฉิน: ${contact.name}';
    }

    // ตั้งค่าการแจ้งเตือนสำหรับ Android
    final androidDetails = AndroidNotificationDetails(
      EMERGENCY_CHANNEL_ID,
      'การแจ้งเตือนฉุกเฉิน',
      channelDescription: 'แสดงเมื่อตรวจพบการล้มหรือการชน',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      vibrationPattern: vibrationEnabled
          ? Int64List.fromList([0, 500, 1000, 500, 1000, 500])
          : null,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    // ตั้งค่าการแจ้งเตือนสำหรับ iOS
    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // รวมการตั้งค่าสำหรับทุกแพลตฟอร์ม
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // แสดงการแจ้งเตือน
    await _notificationsPlugin.show(
      FALL_NOTIFICATION_ID,
      'ตรวจพบการล้ม!',
      'แตะเพื่อดำเนินการต่อ$contactInfo',
      notificationDetails,
      payload: json.encode({'type': 'fall_detection', 'data': fallData}),
    );
  }

  /// แสดงการแจ้งเตือนเมื่อตรวจพบการชน
  Future<void> showCrashDetectionNotification(
      Map<String, dynamic> crashData) async {
    final prefs = await SharedPreferences.getInstance();
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    // ดึงข้อมูลผู้ติดต่อฉุกเฉิน
    final contact = await _contactsService.getPrimaryContact();
    String contactInfo = '';
    if (contact != null && contact.name.isNotEmpty) {
      contactInfo = '\nผู้ติดต่อฉุกเฉิน: ${contact.name}';
    }

    // ตั้งค่าการแจ้งเตือนสำหรับ Android
    final androidDetails = AndroidNotificationDetails(
      EMERGENCY_CHANNEL_ID,
      'การแจ้งเตือนฉุกเฉิน',
      channelDescription: 'แสดงเมื่อตรวจพบการล้มหรือการชน',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      vibrationPattern: vibrationEnabled
          ? Int64List.fromList([0, 500, 1000, 500, 1000, 500])
          : null,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    // ตั้งค่าการแจ้งเตือนสำหรับ iOS
    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // รวมการตั้งค่าสำหรับทุกแพลตฟอร์ม
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // ข้อมูลตำแหน่ง (ถ้ามี)
    String locationInfo = '';
    if (crashData.containsKey('location')) {
      final location = crashData['location'];
      if (location is Map &&
          location.containsKey('latitude') &&
          location.containsKey('longitude')) {
        locationInfo =
            '\nพิกัด: ${location['latitude']}, ${location['longitude']}';
      }
    }

    // แสดงการแจ้งเตือน
    await _notificationsPlugin.show(
      CRASH_NOTIFICATION_ID,
      'ตรวจพบการชน!',
      'แตะเพื่อดำเนินการต่อ$locationInfo$contactInfo',
      notificationDetails,
      payload: json.encode({'type': 'crash_detection', 'data': crashData}),
    );
  }

  /// แสดงการแจ้งเตือนจากเบื้องหลัง (ใช้สำหรับ iOS)
  Future<void> showBackgroundNotification(
    String title,
    String body,
    Map<String, dynamic>? payload,
  ) async {
    // สร้างการแจ้งเตือนด้วยความสำคัญสูง
    final androidDetails = AndroidNotificationDetails(
      EMERGENCY_CHANNEL_ID,
      'การแจ้งเตือนฉุกเฉิน',
      channelDescription: 'แจ้งเตือนจากเบื้องหลัง',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // สร้าง ID แบบไม่ซ้ำกัน
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // แสดงการแจ้งเตือน
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload != null ? json.encode(payload) : null,
    );
  }

  /// แสดงการแจ้งเตือนเบื้องหลังเมื่อแอปทำงานในโหมดเบื้องหลัง
  Future<void> showForegroundNotification() async {
    // ตั้งค่าการแจ้งเตือนสำหรับ Android
    const androidDetails = AndroidNotificationDetails(
      FOREGROUND_CHANNEL_ID,
      'การทำงานเบื้องหลัง',
      channelDescription: 'แสดงเมื่อแอปกำลังทำงานในโหมดเบื้องหลัง',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
    );

    // ตั้งค่าการแจ้งเตือนสำหรับ iOS
    const iOSDetails = DarwinNotificationDetails(
      presentSound: false,
    );

    // รวมการตั้งค่าสำหรับทุกแพลตฟอร์ม
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // แสดงการแจ้งเตือน
    await _notificationsPlugin.show(
      FOREGROUND_NOTIFICATION_ID,
      'การตรวจจับกำลังทำงาน',
      'แอปกำลังตรวจจับการล้มและการชนในโหมดเบื้องหลัง',
      notificationDetails,
    );
  }

  /// แสดงการแจ้งเตือนเตือนความจำ
  Future<void> showReminderNotification(String title, String body) async {
    // ตั้งค่าการแจ้งเตือนสำหรับ Android
    const androidDetails = AndroidNotificationDetails(
      REMINDER_CHANNEL_ID,
      'การแจ้งเตือนทั่วไป',
      channelDescription: 'แสดงการแจ้งเตือนทั่วไปของแอป',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    // ตั้งค่าการแจ้งเตือนสำหรับ iOS
    const iOSDetails = DarwinNotificationDetails(
      presentSound: false,
    );

    // รวมการตั้งค่าสำหรับทุกแพลตฟอร์ม
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // แสดงการแจ้งเตือน
    await _notificationsPlugin.show(
      REMINDER_NOTIFICATION_ID,
      title,
      body,
      notificationDetails,
    );
  }

  /// ยกเลิกการแจ้งเตือนด้วย ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// ยกเลิกการแจ้งเตือนทั้งหมด
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

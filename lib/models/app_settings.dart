import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // การตั้งค่าการตรวจจับ
  bool fallDetectionEnabled;
  bool crashDetectionEnabled;
  bool motionBasedDetection;
  bool barometerEnabled;

  // การตั้งค่าความไว
  String fallSensitivity;
  String crashSensitivity;
  String motionSensitivity;
  String barometerSensitivity;

  // การตั้งค่าการเริ่มต้นอัตโนมัติ
  bool autoStartOnBoot;
  bool runInBackground;

  // การตั้งค่าการแจ้งเตือน
  bool vibrationEnabled;
  bool soundAlertEnabled;
  int fallCountdownSeconds;
  int crashCountdownSeconds;

  AppSettings({
    this.fallDetectionEnabled = false,
    this.crashDetectionEnabled = false,
    this.motionBasedDetection = false,
    this.barometerEnabled = true,
    this.fallSensitivity = 'medium',
    this.crashSensitivity = 'medium',
    this.motionSensitivity = 'medium',
    this.barometerSensitivity = 'medium',
    this.autoStartOnBoot = false,
    this.runInBackground = true,
    this.vibrationEnabled = true,
    this.soundAlertEnabled = true,
    this.fallCountdownSeconds = 30,
    this.crashCountdownSeconds = 20,
  });

  // คัดลอกและอัพเดทค่า
  AppSettings copyWith({
    bool? fallDetectionEnabled,
    bool? crashDetectionEnabled,
    bool? motionBasedDetection,
    bool? barometerEnabled,
    String? fallSensitivity,
    String? crashSensitivity,
    String? motionSensitivity,
    String? barometerSensitivity,
    bool? autoStartOnBoot,
    bool? runInBackground,
    bool? vibrationEnabled,
    bool? soundAlertEnabled,
    int? fallCountdownSeconds,
    int? crashCountdownSeconds,
  }) {
    return AppSettings(
      fallDetectionEnabled: fallDetectionEnabled ?? this.fallDetectionEnabled,
      crashDetectionEnabled:
          crashDetectionEnabled ?? this.crashDetectionEnabled,
      motionBasedDetection: motionBasedDetection ?? this.motionBasedDetection,
      barometerEnabled: barometerEnabled ?? this.barometerEnabled,
      fallSensitivity: fallSensitivity ?? this.fallSensitivity,
      crashSensitivity: crashSensitivity ?? this.crashSensitivity,
      motionSensitivity: motionSensitivity ?? this.motionSensitivity,
      barometerSensitivity: barometerSensitivity ?? this.barometerSensitivity,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      runInBackground: runInBackground ?? this.runInBackground,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundAlertEnabled: soundAlertEnabled ?? this.soundAlertEnabled,
      fallCountdownSeconds: fallCountdownSeconds ?? this.fallCountdownSeconds,
      crashCountdownSeconds:
          crashCountdownSeconds ?? this.crashCountdownSeconds,
    );
  }

  // แปลงจาก JSON Map
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fallDetectionEnabled: json['fallDetectionEnabled'] as bool? ?? false,
      crashDetectionEnabled: json['crashDetectionEnabled'] as bool? ?? false,
      motionBasedDetection: json['motionBasedDetection'] as bool? ?? false,
      barometerEnabled: json['barometerEnabled'] as bool? ?? true,
      fallSensitivity: json['fallSensitivity'] as String? ?? 'medium',
      crashSensitivity: json['crashSensitivity'] as String? ?? 'medium',
      motionSensitivity: json['motionSensitivity'] as String? ?? 'medium',
      barometerSensitivity: json['barometerSensitivity'] as String? ?? 'medium',
      autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
      runInBackground: json['runInBackground'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      soundAlertEnabled: json['soundAlertEnabled'] as bool? ?? true,
      fallCountdownSeconds: json['fallCountdownSeconds'] as int? ?? 30,
      crashCountdownSeconds: json['crashCountdownSeconds'] as int? ?? 20,
    );
  }

  // แปลงเป็น JSON Map
  Map<String, dynamic> toJson() {
    return {
      'fallDetectionEnabled': fallDetectionEnabled,
      'crashDetectionEnabled': crashDetectionEnabled,
      'motionBasedDetection': motionBasedDetection,
      'barometerEnabled': barometerEnabled,
      'fallSensitivity': fallSensitivity,
      'crashSensitivity': crashSensitivity,
      'motionSensitivity': motionSensitivity,
      'barometerSensitivity': barometerSensitivity,
      'autoStartOnBoot': autoStartOnBoot,
      'runInBackground': runInBackground,
      'vibrationEnabled': vibrationEnabled,
      'soundAlertEnabled': soundAlertEnabled,
      'fallCountdownSeconds': fallCountdownSeconds,
      'crashCountdownSeconds': crashCountdownSeconds,
    };
  }

  // สำหรับแปลง AppSettings เป็น JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // สำหรับสร้าง AppSettings จาก JSON string
  factory AppSettings.fromJsonString(String jsonString) {
    return AppSettings.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  // บันทึกการตั้งค่าลงใน SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // บันทึกการตั้งค่าการตรวจจับ
    await prefs.setBool('fall_detection_enabled', fallDetectionEnabled);
    await prefs.setBool('crash_detection_enabled', crashDetectionEnabled);
    await prefs.setBool('motion_based_detection', motionBasedDetection);
    await prefs.setBool('enable_barometer_for_fall', barometerEnabled);

    // บันทึกการตั้งค่าความไว
    await prefs.setString('fall_detection_sensitivity', fallSensitivity);
    await prefs.setString('crash_detection_sensitivity', crashSensitivity);
    await prefs.setString('motion_detection_sensitivity', motionSensitivity);
    await prefs.setString('barometer_sensitivity', barometerSensitivity);

    // บันทึกการตั้งค่าการเริ่มต้นอัตโนมัติ
    await prefs.setBool('auto_start_on_boot', autoStartOnBoot);
    await prefs.setBool('run_in_background', runInBackground);

    // บันทึกการตั้งค่าการแจ้งเตือน
    await prefs.setBool('vibration_enabled', vibrationEnabled);
    await prefs.setBool('sound_alert_enabled', soundAlertEnabled);
    await prefs.setInt('fall_countdown_seconds', fallCountdownSeconds);
    await prefs.setInt('crash_countdown_seconds', crashCountdownSeconds);

    // บันทึกทั้งหมดเป็น JSON สำรอง
    await prefs.setString('app_settings_json', toJsonString());
  }

  // โหลดการตั้งค่าจาก SharedPreferences
  static Future<AppSettings> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // ลองโหลดจาก JSON สำรอง
    final jsonString = prefs.getString('app_settings_json');
    if (jsonString != null) {
      try {
        return AppSettings.fromJsonString(jsonString);
      } catch (e) {
        print('Error loading settings from JSON: $e');
        // ถ้าโหลดจาก JSON ไม่ได้ จะโหลดจากการตั้งค่าแยก
      }
    }

    // โหลดแต่ละค่าแยกกัน
    return AppSettings(
      // การตั้งค่าการตรวจจับ
      fallDetectionEnabled: prefs.getBool('fall_detection_enabled') ?? false,
      crashDetectionEnabled: prefs.getBool('crash_detection_enabled') ?? false,
      motionBasedDetection: prefs.getBool('motion_based_detection') ?? false,
      barometerEnabled: prefs.getBool('enable_barometer_for_fall') ?? true,

      // การตั้งค่าความไว
      fallSensitivity:
          prefs.getString('fall_detection_sensitivity') ?? 'medium',
      crashSensitivity:
          prefs.getString('crash_detection_sensitivity') ?? 'medium',
      motionSensitivity:
          prefs.getString('motion_detection_sensitivity') ?? 'medium',
      barometerSensitivity:
          prefs.getString('barometer_sensitivity') ?? 'medium',

      // การตั้งค่าการเริ่มต้นอัตโนมัติ
      autoStartOnBoot: prefs.getBool('auto_start_on_boot') ?? false,
      runInBackground: prefs.getBool('run_in_background') ?? true,

      // การตั้งค่าการแจ้งเตือน
      vibrationEnabled: prefs.getBool('vibration_enabled') ?? true,
      soundAlertEnabled: prefs.getBool('sound_alert_enabled') ?? true,
      fallCountdownSeconds: prefs.getInt('fall_countdown_seconds') ?? 30,
      crashCountdownSeconds: prefs.getInt('crash_countdown_seconds') ?? 20,
    );
  }

  // รีเซ็ตการตั้งค่าเป็นค่าเริ่มต้น
  static AppSettings getDefaultSettings() {
    return AppSettings(
      fallDetectionEnabled: false,
      crashDetectionEnabled: false,
      motionBasedDetection: false,
      barometerEnabled: true,
      fallSensitivity: 'medium',
      crashSensitivity: 'medium',
      motionSensitivity: 'medium',
      barometerSensitivity: 'medium',
      autoStartOnBoot: false,
      runInBackground: true,
      vibrationEnabled: true,
      soundAlertEnabled: true,
      fallCountdownSeconds: 30,
      crashCountdownSeconds: 20,
    );
  }

  @override
  String toString() {
    return 'AppSettings(fallDetectionEnabled: $fallDetectionEnabled, crashDetectionEnabled: $crashDetectionEnabled, '
        'motionBasedDetection: $motionBasedDetection, barometerEnabled: $barometerEnabled)';
  }
}

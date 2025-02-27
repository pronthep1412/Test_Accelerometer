import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';

/// บริการสำหรับจัดการการตั้งค่าแอป
class SettingsService {
  // เก็บการตั้งค่าแอปปัจจุบัน
  late AppSettings _settings;

  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal() {
    // เริ่มต้นด้วยค่าเริ่มต้น
    _settings = AppSettings();
  }

  /// โหลดการตั้งค่าจาก SharedPreferences
  Future<AppSettings> loadSettings() async {
    _settings = await AppSettings.loadFromPrefs();
    return _settings;
  }

  /// บันทึกการตั้งค่าลงใน SharedPreferences
  Future<void> saveSettings() async {
    await _settings.saveToPrefs();
  }

  /// รีเซ็ตการตั้งค่าทั้งหมดเป็นค่าเริ่มต้น
  Future<void> resetSettings() async {
    _settings = AppSettings.getDefaultSettings();
    await saveSettings();
  }

  /// อัพเดทการตั้งค่า
  Future<void> updateSettings({
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
  }) async {
    _settings = _settings.copyWith(
      fallDetectionEnabled: fallDetectionEnabled,
      crashDetectionEnabled: crashDetectionEnabled,
      motionBasedDetection: motionBasedDetection,
      barometerEnabled: barometerEnabled,
      fallSensitivity: fallSensitivity,
      crashSensitivity: crashSensitivity,
      motionSensitivity: motionSensitivity,
      barometerSensitivity: barometerSensitivity,
      autoStartOnBoot: autoStartOnBoot,
      runInBackground: runInBackground,
      vibrationEnabled: vibrationEnabled,
      soundAlertEnabled: soundAlertEnabled,
      fallCountdownSeconds: fallCountdownSeconds,
      crashCountdownSeconds: crashCountdownSeconds,
    );

    await saveSettings();
  }

  /// ดึงการตั้งค่าปัจจุบัน
  AppSettings get settings => _settings;

  /// ตั้งค่าการเริ่มต้นอัตโนมัติ
  Future<void> setAutoStartOnBoot(bool enabled) async {
    _settings = _settings.copyWith(autoStartOnBoot: enabled);
    await saveSettings();
  }

  /// ตั้งค่าการทำงานในเบื้องหลัง
  Future<void> setRunInBackground(bool enabled) async {
    _settings = _settings.copyWith(runInBackground: enabled);
    await saveSettings();
  }

  /// เปิด/ปิดการตรวจจับการล้ม
  Future<void> setFallDetectionEnabled(bool enabled) async {
    _settings = _settings.copyWith(fallDetectionEnabled: enabled);
    await saveSettings();
  }

  /// เปิด/ปิดการตรวจจับการชน
  Future<void> setCrashDetectionEnabled(bool enabled) async {
    _settings = _settings.copyWith(crashDetectionEnabled: enabled);
    await saveSettings();
  }

  /// เปิด/ปิดการใช้งาน Barometer
  Future<void> setBarometerEnabled(bool enabled) async {
    _settings = _settings.copyWith(barometerEnabled: enabled);
    await saveSettings();
  }

  /// เปิด/ปิดการตรวจจับตามการเคลื่อนไหว
  Future<void> setMotionBasedDetection(bool enabled) async {
    _settings = _settings.copyWith(motionBasedDetection: enabled);
    await saveSettings();
  }

  /// ตั้งค่าความไวสำหรับการตรวจจับการล้ม
  Future<void> setFallSensitivity(String sensitivity) async {
    _settings = _settings.copyWith(fallSensitivity: sensitivity);
    await saveSettings();
  }

  /// ตั้งค่าความไวสำหรับการตรวจจับการชน
  Future<void> setCrashSensitivity(String sensitivity) async {
    _settings = _settings.copyWith(crashSensitivity: sensitivity);
    await saveSettings();
  }

  /// ตั้งค่าความไวสำหรับการตรวจจับการเคลื่อนไหว
  Future<void> setMotionSensitivity(String sensitivity) async {
    _settings = _settings.copyWith(motionSensitivity: sensitivity);
    await saveSettings();
  }

  /// ตั้งค่าความไวสำหรับ Barometer
  Future<void> setBarometerSensitivity(String sensitivity) async {
    _settings = _settings.copyWith(barometerSensitivity: sensitivity);
    await saveSettings();
  }

  /// ตั้งค่าเวลานับถอยหลังสำหรับการล้ม
  Future<void> setFallCountdownSeconds(int seconds) async {
    _settings = _settings.copyWith(fallCountdownSeconds: seconds);
    await saveSettings();
  }

  /// ตั้งค่าเวลานับถอยหลังสำหรับการชน
  Future<void> setCrashCountdownSeconds(int seconds) async {
    _settings = _settings.copyWith(crashCountdownSeconds: seconds);
    await saveSettings();
  }

  /// ตั้งค่าการสั่น
  Future<void> setVibrationEnabled(bool enabled) async {
    _settings = _settings.copyWith(vibrationEnabled: enabled);
    await saveSettings();
  }

  /// ตั้งค่าเสียงเตือน
  Future<void> setSoundAlertEnabled(bool enabled) async {
    _settings = _settings.copyWith(soundAlertEnabled: enabled);
    await saveSettings();
  }

  /// ส่งออกการตั้งค่าเป็น JSON
  String exportSettingsAsJson() {
    return jsonEncode(_settings.toJson());
  }

  /// นำเข้าการตั้งค่าจาก JSON
  Future<bool> importSettingsFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      _settings = AppSettings.fromJson(json);
      await saveSettings();
      return true;
    } catch (e) {
      print('Error importing settings: $e');
      return false;
    }
  }
}

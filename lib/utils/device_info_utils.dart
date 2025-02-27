import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ยูทิลิตี้สำหรับรับข้อมูลอุปกรณ์และแอปพลิเคชัน
class DeviceInfoUtils {
  // คงค่าตัวแปรสำหรับข้อมูลที่ไม่เปลี่ยนแปลง
  static DeviceInfoPlugin? _deviceInfoPlugin;
  static AndroidDeviceInfo? _androidInfo;
  static IosDeviceInfo? _iosInfo;
  static PackageInfo? _packageInfo;

  /// เริ่มต้นและโหลดข้อมูลอุปกรณ์
  static Future<void> initialize() async {
    _deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      _androidInfo = await _deviceInfoPlugin!.androidInfo;
    } else if (Platform.isIOS) {
      _iosInfo = await _deviceInfoPlugin!.iosInfo;
    }

    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// รับข้อมูลรุ่นอุปกรณ์
  static String getDeviceModel() {
    if (_androidInfo != null) {
      return '${_androidInfo!.manufacturer} ${_androidInfo!.model}';
    } else if (_iosInfo != null) {
      return _iosInfo!.name;
    }
    return 'Unknown Device';
  }

  /// รับข้อมูลเวอร์ชันระบบปฏิบัติการ
  static String getOSVersion() {
    if (_androidInfo != null) {
      return 'Android ${_androidInfo!.version.release} (SDK ${_androidInfo!.version.sdkInt})';
    } else if (_iosInfo != null) {
      return 'iOS ${_iosInfo!.systemVersion}';
    }
    return 'Unknown OS';
  }

  /// รับข้อมูลเวอร์ชันแอป
  static String getAppVersion() {
    if (_packageInfo != null) {
      return '${_packageInfo!.version} (${_packageInfo!.buildNumber})';
    }
    return 'Unknown Version';
  }

  /// รับข้อมูลชื่อแอป
  static String getAppName() {
    if (_packageInfo != null) {
      return _packageInfo!.appName;
    }
    return 'Unknown App';
  }

  /// รับข้อมูลเซ็นเซอร์ที่รองรับ (สำหรับ Android)
  static Future<List<String>> getSupportedSensors() async {
    if (!Platform.isAndroid) {
      return ['ไม่สามารถตรวจสอบได้บนอุปกรณ์นี้'];
    }

    try {
      // หมายเหตุ: ในการใช้งานจริงต้องเพิ่มโค้ดสำหรับตรวจสอบเซ็นเซอร์ที่รองรับ
      // ในที่นี้จะเป็นตัวอย่างเท่านั้น
      return [
        'Accelerometer',
        'Gyroscope',
        'Barometer (Pressure)',
        'Proximity',
        'Light',
      ];
    } catch (e) {
      return ['ไม่สามารถตรวจสอบได้: $e'];
    }
  }

  /// ตรวจสอบว่ารองรับ Barometer หรือไม่
  static Future<bool> isBarometerSupported() async {
    // หมายเหตุ: ในการใช้งานจริงต้องเพิ่มโค้ดสำหรับตรวจสอบ Barometer
    // ในที่นี้จะเป็นตัวอย่างเท่านั้น
    if (_androidInfo != null) {
      // ทดสอบเรียกใช้ barometer ใน Android
      try {
        // เช็คเบื้องต้นโดยดูจากรุ่นที่รู้ว่ารองรับ
        final model = _androidInfo!.model.toLowerCase();
        if (model.contains('pixel') ||
            model.contains('samsung') ||
            model.contains('huawei')) {
          return true;
        }
      } catch (e) {
        print('Error checking barometer: $e');
      }
    } else if (_iosInfo != null) {
      // เช็คเบื้องต้นโดยดูจากรุ่นที่รู้ว่ารองรับ
      try {
        final model = _iosInfo!.name.toLowerCase();
        if (model.contains('iphone 6') ||
            model.contains('iphone 7') ||
            model.contains('iphone 8') ||
            model.contains('iphone x') ||
            model.contains('iphone 11') ||
            model.contains('iphone 12') ||
            model.contains('iphone 13') ||
            model.contains('iphone 14')) {
          return true;
        }
      } catch (e) {
        print('Error checking barometer: $e');
      }
    }

    return false;
  }

  /// รับข้อมูลอุปกรณ์ทั้งหมดสำหรับการส่งรายงานข้อผิดพลาด
  static Map<String, dynamic> getAllDeviceInfo() {
    final Map<String, dynamic> deviceInfo = {
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'appName': getAppName(),
      'appVersion': getAppVersion(),
      'deviceModel': getDeviceModel(),
      'osVersion': getOSVersion(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_androidInfo != null) {
      deviceInfo['androidInfo'] = {
        'manufacturer': _androidInfo!.manufacturer,
        'model': _androidInfo!.model,
        'sdkInt': _androidInfo!.version.sdkInt,
        'release': _androidInfo!.version.release,
        'brand': _androidInfo!.brand,
        'device': _androidInfo!.device,
        'isPhysicalDevice': _androidInfo!.isPhysicalDevice,
      };
    }

    if (_iosInfo != null) {
      deviceInfo['iosInfo'] = {
        'name': _iosInfo!.name,
        'model': _iosInfo!.model,
        'systemName': _iosInfo!.systemName,
        'systemVersion': _iosInfo!.systemVersion,
        'localizedModel': _iosInfo!.localizedModel,
        'isPhysicalDevice': _iosInfo!.isPhysicalDevice,
      };
    }

    return deviceInfo;
  }

  /// ตรวจสอบว่าเป็นการรันบนอุปกรณ์จริงหรือไม่
  static bool isPhysicalDevice() {
    if (_androidInfo != null) {
      return _androidInfo!.isPhysicalDevice;
    } else if (_iosInfo != null) {
      return _iosInfo!.isPhysicalDevice;
    }
    return false;
  }

  /// ตรวจสอบเวอร์ชันของแอปกับเวอร์ชันล่าสุด
  static Future<bool> isLatestVersion(String latestVersion) async {
    if (_packageInfo == null) {
      return false;
    }

    final currentVersion = _packageInfo!.version;

    return _compareVersions(currentVersion, latestVersion) >= 0;
  }

  /// เปรียบเทียบเวอร์ชัน
  ///
  /// คืนค่า > 0 ถ้า v1 > v2
  /// คืนค่า = 0 ถ้า v1 = v2
  /// คืนค่า < 0 ถ้า v1 < v2
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    // เติม 0 ให้กับเวอร์ชันที่สั้นกว่า
    while (v1Parts.length < v2Parts.length) {
      v1Parts.add(0);
    }
    while (v2Parts.length < v1Parts.length) {
      v2Parts.add(0);
    }

    // เปรียบเทียบทีละส่วน
    for (int i = 0; i < v1Parts.length; i++) {
      final comparison = v1Parts[i].compareTo(v2Parts[i]);
      if (comparison != 0) {
        return comparison;
      }
    }

    return 0; // เวอร์ชันเท่ากัน
  }

  /// ตรวจสอบว่าอุปกรณ์รองรับ Gyroscope หรือไม่
  static Future<bool> isGyroscopeSupported() async {
    // หมายเหตุ: ในการใช้งานจริงต้องเพิ่มโค้ดสำหรับตรวจสอบ Gyroscope
    // ในที่นี้จะเป็นตัวอย่างเท่านั้น
    if (_androidInfo != null) {
      try {
        final model = _androidInfo!.model.toLowerCase();
        // โทรศัพท์ระดับกลางถึงไฮเอนด์ส่วนใหญ่หลังปี 2015 มี gyroscope
        if (model.contains('pixel') ||
            model.contains('samsung') ||
            model.contains('huawei') ||
            model.contains('xiaomi') ||
            model.contains('oneplus')) {
          return true;
        }
      } catch (e) {
        print('Error checking gyroscope: $e');
      }
    } else if (_iosInfo != null) {
      // iPhone ทุกรุ่นมี gyroscope
      return true;
    }

    return false;
  }

  /// ตรวจสอบว่าอุปกรณ์รองรับ Accelerometer หรือไม่
  static Future<bool> isAccelerometerSupported() async {
    // โทรศัพท์สมาร์ทโฟนทุกเครื่องมักจะมี accelerometer
    return true;
  }

  /// ดึงข้อมูลเกี่ยวกับแบตเตอรี่
  static Future<Map<String, dynamic>> getBatteryInfo() async {
    // หมายเหตุ: ในการใช้งานจริงต้องใช้แพ็กเกจ battery_plus
    // ในที่นี้จะเป็นตัวอย่างเท่านั้น
    return {
      'level': 'ไม่สามารถอ่านได้',
      'state': 'ไม่สามารถอ่านได้',
    };
  }

  /// ตรวจสอบข้อมูลเครือข่าย
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    // หมายเหตุ: ในการใช้งานจริงต้องใช้แพ็กเกจ connectivity_plus
    // ในที่นี้จะเป็นตัวอย่างเท่านั้น
    return {
      'type': 'ไม่สามารถอ่านได้',
      'connected': 'ไม่สามารถอ่านได้',
    };
  }
}

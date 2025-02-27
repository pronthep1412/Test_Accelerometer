import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ยูทิลิตี้สำหรับการขอสิทธิ์ต่างๆ และจัดการการขอสิทธิ์ที่ได้รับการปฏิเสธ
class PermissionUtil {
  /// ชื่อและรายละเอียดของสิทธิ์ต่างๆ
  static final Map<Permission, String> _permissionNames = {
    Permission.location: 'ตำแหน่ง',
    Permission.sensors: 'เซ็นเซอร์',
    Permission.activityRecognition: 'การรับรู้กิจกรรม',
    Permission.notification: 'การแจ้งเตือน',
  };

  static final Map<Permission, String> _permissionDescriptions = {
    Permission.location: 'ใช้สำหรับบันทึกตำแหน่งเมื่อเกิดเหตุฉุกเฉิน',
    Permission.sensors: 'ใช้สำหรับตรวจจับการล้มและการชน',
    Permission.activityRecognition: 'ใช้สำหรับตรวจจับกิจกรรมและประหยัดพลังงาน',
    Permission.notification: 'ใช้สำหรับแจ้งเตือนเมื่อเกิดเหตุฉุกเฉิน',
  };

  /// ขอสิทธิ์ที่จำเป็นสำหรับแอพ
  static Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final deniedCount = prefs.getInt('permission_denied_count') ?? 0;

    // ขอสิทธิ์
    final statuses = await permissions.request();

    // บันทึกจำนวนครั้งที่ปฏิเสธ
    int newDeniedCount = deniedCount;
    for (final permission in permissions) {
      if (statuses[permission]!.isDenied ||
          statuses[permission]!.isPermanentlyDenied) {
        newDeniedCount++;
      }
    }

    await prefs.setInt('permission_denied_count', newDeniedCount);

    return statuses;
  }

  /// ตรวจสอบสถานะของสิทธิ์ทั้งหมด
  static Future<Map<Permission, PermissionStatus>> checkPermissionStatuses(
    List<Permission> permissions,
  ) async {
    final Map<Permission, PermissionStatus> statuses = {};

    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  /// แสดงไดอะล็อกขอสิทธิ์หลังจากถูกปฏิเสธ
  static Future<bool> showPermissionRationaleDialog(
    BuildContext context,
    Permission permission,
  ) async {
    if (!_permissionNames.containsKey(permission)) {
      return false;
    }

    final permissionName = _permissionNames[permission]!;
    final permissionDescription = _permissionDescriptions[permission]!;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ต้องการสิทธิ์ $permissionName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('แอปนี้ต้องการสิทธิ์ $permissionName'),
            const SizedBox(height: 8),
            Text(permissionDescription),
            const SizedBox(height: 16),
            const Text(
              'โปรดให้สิทธิ์ในการตั้งค่าแอปเพื่อให้แอปทำงานได้อย่างถูกต้อง',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ไปที่การตั้งค่า'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// แสดงไดอะล็อกขอสิทธิ์ก่อนที่จะดำเนินการขอ
  static Future<bool> showPermissionPreRequestDialog(
    BuildContext context,
    Permission permission,
  ) async {
    if (!_permissionNames.containsKey(permission)) {
      return false;
    }

    final permissionName = _permissionNames[permission]!;
    final permissionDescription = _permissionDescriptions[permission]!;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('การขอสิทธิ์ $permissionName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('แอปจะขอสิทธิ์ $permissionName จากคุณในขั้นตอนถัดไป'),
            const SizedBox(height: 8),
            Text(permissionDescription),
            const SizedBox(height: 16),
            const Text(
              'โปรดกดอนุญาตเพื่อให้คุณลักษณะทั้งหมดของแอปทำงานได้อย่างถูกต้อง',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ไม่อนุญาต'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ดำเนินการต่อ'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// ขอสิทธิ์โดยแสดงคำอธิบายก่อน
  static Future<PermissionStatus> requestPermissionWithRationale(
    BuildContext context,
    Permission permission,
  ) async {
    final shouldRequest =
        await showPermissionPreRequestDialog(context, permission);

    if (!shouldRequest) {
      return PermissionStatus.denied;
    }

    final status = await permission.request();

    if (status.isPermanentlyDenied) {
      final shouldOpenSettings =
          await showPermissionRationaleDialog(context, permission);

      if (shouldOpenSettings) {
        await openAppSettings();
      }
    }

    return status;
  }

  /// จัดการกับสิทธิ์ที่ถูกปฏิเสธและแสดงข้อความที่เหมาะสม
  static Future<void> handleDeniedPermission(
    BuildContext context,
    Permission permission,
  ) async {
    final permissionName = _permissionNames[permission] ?? 'ที่ต้องการ';

    final status = await permission.status;

    if (status.isPermanentlyDenied) {
      final shouldOpenSettings =
          await showPermissionRationaleDialog(context, permission);

      if (shouldOpenSettings) {
        await openAppSettings();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('คุณปฏิเสธสิทธิ์ $permissionName บางคุณลักษณะอาจไม่ทำงาน'),
          action: SnackBarAction(
            label: 'ลองอีกครั้ง',
            onPressed: () async {
              await requestPermissionWithRationale(context, permission);
            },
          ),
        ),
      );
    }
  }

  /// ตรวจสอบว่าสิทธิ์ Location ถูกเปิดใช้งานหรือไม่
  static Future<bool> isLocationServiceEnabled() async {
    return await Permission.location.serviceStatus.isEnabled;
  }

  /// แสดง dialog ขอให้เปิดบริการตำแหน่ง
  static Future<bool> showLocationServiceDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('โปรดเปิดบริการตำแหน่ง'),
        content: const Text(
          'การตรวจจับการชนต้องใช้บริการตำแหน่ง โปรดเปิดบริการนี้ในการตั้งค่าอุปกรณ์',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ไปที่การตั้งค่า'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

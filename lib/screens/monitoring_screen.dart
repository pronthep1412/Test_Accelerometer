import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../services/background/notification_service.dart';
import '../services/detection/detection_manager.dart';
import '../widgets/detection_status_card.dart';
import '../widgets/emergency_alert_dialog.dart';
import 'settings_screen.dart';
import '../widgets/sensor_data_display.dart';
import 'alert_screen.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  _MonitoringScreenState createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with WidgetsBindingObserver {
  final DetectionManager _detectionManager = DetectionManager();

  late Timer _updateTimer;
  Map<String, dynamic> _currentSensorData = {};
  bool _fallDetectionEnabled = false;
  bool _crashDetectionEnabled = false;
  bool _motionBasedEnabled = false;
  bool _barometerEnabled = false;

  String _status = 'พร้อมใช้งาน';
  bool _isDetecting = false;

  // ข้อมูลผู้ติดต่อฉุกเฉิน
  String _emergencyContact = '';
  String _emergencyPhone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // กำหนด callbacks สำหรับ detection manager
    _detectionManager.onDetectionEvent = _handleDetectionEvent;
    _detectionManager.onFalseAlarm = _handleFalseAlarm;

    // โหลดการตั้งค่าและข้อมูลผู้ติดต่อฉุกเฉิน
    _loadSettings();
    _loadEmergencyContact();

    // ขอสิทธิ์ที่จำเป็น
    _requestPermissions();

    // อัพเดทข้อมูลเซ็นเซอร์ทุกๆ 100 มิลลิวินาที
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateSensorData();
    });

    // Timer.periodic(const Duration(minutes: 1), (timer) async {
  
    //   if (timer.tick % 1 == 0) {
    //     final notificationService = NotificationService();
    //     await notificationService.initialize();
    //     final success = await notificationService.testNotification();
    //     print(
    //         'BackgroundService: ทดสอบการแจ้งเตือนในรอบที่ ${timer.tick} - ${success ? "สำเร็จ" : "ล้มเหลว"}');
    //   }
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // แอพกลับมาทำงานในหน้าจอ - อัพเดทสถานะ
      _refreshSettings();
    }
  }

  Future<void> _loadSettings() async {
    await _detectionManager.loadSettings();
    _refreshSettings();
  }

  void _updateSensorData() {
    final sensorData = _detectionManager.getCurrentSensorData();

    setState(() {
      _currentSensorData = sensorData;
    });
  }

  void _refreshSettings() {
    setState(() {
      _fallDetectionEnabled = _detectionManager.isFallDetectionEnabled;
      _crashDetectionEnabled = _detectionManager.isCrashDetectionEnabled;
      _motionBasedEnabled = _detectionManager.isMotionBasedDetectionEnabled;
      _isDetecting = _detectionManager.isAnyDetectionActive;

      if (_isDetecting) {
        if (_fallDetectionEnabled && _crashDetectionEnabled) {
          _status = 'กำลังตรวจจับการล้มและการชน';
        } else if (_fallDetectionEnabled) {
          _status = 'กำลังตรวจจับการล้ม';
        } else if (_crashDetectionEnabled) {
          _status = 'กำลังตรวจจับการชน';
        }

        if (_motionBasedEnabled) {
          _status += ' (ตามการเคลื่อนไหว)';
        }
      } else {
        _status = 'พร้อมใช้งาน';
      }
    });
  }

  Future<void> _loadEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyContact =
          prefs.getString('emergency_contact_name') ?? 'ยังไม่ได้ตั้งค่า';
      _emergencyPhone = prefs.getString('emergency_contact_phone') ?? '';
    });
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sensors,
      Permission.activityRecognition,
      Permission.notification,
    ].request();

    // ตรวจสอบสถานะการขอสิทธิ์
    if (statuses[Permission.location]!.isDenied) {
      _showPermissionDialog('Location');
    }

    if (statuses[Permission.sensors]!.isDenied) {
      _showPermissionDialog('Sensors');
    }

    if (statuses[Permission.activityRecognition]!.isDenied) {
      _showPermissionDialog('Activity Recognition');
    }

    if (statuses[Permission.notification]!.isDenied) {
      _showPermissionDialog('Notification');
    }
  }

  void _showPermissionDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ต้องการสิทธิ์ $permissionName'),
        content: Text(
            'แอปนี้ต้องการสิทธิ์ $permissionName เพื่อตรวจจับการล้มและการชน'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _toggleFallDetection(bool value) async {
    await _detectionManager.toggleFallDetection(value);
    _refreshSettings();
  }

  void _toggleCrashDetection(bool value) async {
    await _detectionManager.toggleCrashDetection(value);
    _refreshSettings();
  }

  void _toggleMotionBasedDetection(bool value) async {
    await _detectionManager.toggleMotionBasedDetection(value);
    _refreshSettings();
  }

  void _testFallDetection() {
    // สร้างข้อมูลการล้มจำลอง
    final fallData = {
      'type': 'fall',
      'timestamp': DateTime.now().toIso8601String(),
      'max_acceleration': 25.5,
      'avg_post_impact_acceleration': 1.2,
    };

    // เปิดหน้าจอแจ้งเตือน
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertScreen(
          alertType: 'fall',
          eventData: fallData,
        ),
      ),
    );
  }

  void _handleDetectionEvent(Map<String, dynamic> eventData) {
    // แสดง dialog การแจ้งเตือนตามประเภทของเหตุการณ์
    final eventType = eventData['type'];

    if (eventType == 'fall') {
      _showFallAlert(eventData);
    } else if (eventType == 'crash') {
      _showCrashAlert(eventData);
    }
  }

  void _handleFalseAlarm() {
    setState(() {
      _status = 'การแจ้งเตือนถูกยกเลิก';
    });
  }

  void _showFallAlert(Map<String, dynamic> fallData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmergencyAlertDialog(
        title: 'ตรวจพบการล้ม!',
        message: 'ตรวจพบการล้มที่อาจเกิดขึ้น แตะเพื่อตรวจสอบและดำเนินการ',
        eventData: fallData,
        emergencyContact: _emergencyContact,
        emergencyPhone: _emergencyPhone,
        onFalseAlarm: () {
          _detectionManager.toggleFallDetection(true);
          Navigator.pop(context);
          _handleFalseAlarm();
        },
        onEmergencyCall: () {
          _sendEmergencyAlert('การล้ม', fallData);
          Navigator.pop(context);
        },
        countdownSeconds: 30,
        onCountdownFinished: () {
          _sendEmergencyAlert('การล้ม (ไม่มีการตอบสนอง)', fallData);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCrashAlert(Map<String, dynamic> crashData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmergencyAlertDialog(
        title: 'ตรวจพบการชน!',
        message: 'ตรวจพบการชนที่อาจเกิดขึ้น แตะเพื่อตรวจสอบและดำเนินการ',
        eventData: crashData,
        emergencyContact: _emergencyContact,
        emergencyPhone: _emergencyPhone,
        onFalseAlarm: () {
          _detectionManager.toggleCrashDetection(true);
          Navigator.pop(context);
          _handleFalseAlarm();
        },
        onEmergencyCall: () {
          _sendEmergencyAlert('การชน', crashData);
          Navigator.pop(context);
        },
        countdownSeconds: 20,
        onCountdownFinished: () {
          _sendEmergencyAlert('การชน (ไม่มีการตอบสนอง)', crashData);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _testCrashDetection() {
    // สร้างข้อมูลการชนจำลอง
    final crashData = {
      'type': 'crash',
      'timestamp': DateTime.now().toIso8601String(),
      'location': {
        'latitude': 13.736717,
        'longitude': 100.523186,
      },
      'speed': 45.2, // km/h
      'impact_force': 60.5,
      'rotation': 5.2,
      'post_crash_movement': 2.1,
    };

    // เปิดหน้าจอแจ้งเตือน
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertScreen(
          alertType: 'crash',
          eventData: crashData,
        ),
      ),
    );
  }

  void _sendEmergencyAlert(String eventType, Map<String, dynamic> eventData) {
    // ในระบบจริงจะต้องส่ง SMS, โทรศัพท์, แจ้งเตือนไปยังฝ่ายตอบสนองฉุกเฉิน ฯลฯ
    // ในที่นี้จะแสดงการแจ้งเตือนเพื่อเป็นตัวอย่าง

    setState(() {
      _status = 'กำลังส่งการแจ้งเตือนฉุกเฉิน: $eventType';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ส่งการแจ้งเตือนฉุกเฉินไปยัง $_emergencyContact แล้ว'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );

    // ทำงานอื่นๆ ที่จำเป็น เช่น ส่งข้อมูลไปยังเซิร์ฟเวอร์, บันทึกเหตุการณ์ ฯลฯ
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    // อัพเดทข้อมูลหลังจากกลับมาจากหน้าตั้งค่า
    _loadSettings();
    _loadEmergencyContact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบตรวจจับการล้มและการชน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'ตั้งค่า',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // สถานะ
            DetectionStatusCard(
              status: _status,
              isActive: _isDetecting,
            ),

            const SizedBox(height: 24),

            // การตรวจจับการล้ม
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.elderly, color: Colors.blue),
                            const SizedBox(width: 10),
                            const Text(
                              'การตรวจจับการล้ม',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _fallDetectionEnabled,
                          onChanged: _toggleFallDetection,
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'เมื่อเปิดใช้งาน แอปจะตรวจสอบการล้มโดยใช้ข้อมูลจาก accelerometer'),
                    // if (_fallDetectionEnabled) ...[
                    //   const SizedBox(height: 16),
                    //   Row(
                    //     children: [
                    //       Expanded(
                    //         child: Row(
                    //           children: [
                    //             Icon(
                    //               Icons.height,
                    //               color: _barometerEnabled
                    //                   ? Colors.blue
                    //                   : Colors.grey,
                    //               size: 20,
                    //             ),
                    //             const SizedBox(width: 8),
                    //             const Expanded(
                    //               child: Text('ใช้ Barometer'),
                    //             ),
                    //           ],
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // การตรวจจับการชน
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.car_crash, color: Colors.red),
                            const SizedBox(width: 10),
                            const Text(
                              'การตรวจจับการชน',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _crashDetectionEnabled,
                          onChanged: _toggleCrashDetection,
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'เมื่อเปิดใช้งาน แอปจะตรวจสอบการชนโดยใช้ข้อมูลจาก accelerometer, gyroscope และตำแหน่ง GPS'),
                  ],
                ),
              ),
            ),

            // const SizedBox(height: 16),

            // // ตรวจจับตามการเคลื่อนไหว
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             Row(
            //               children: [
            //                 const Icon(Icons.battery_saver,
            //                     color: Colors.green),
            //                 const SizedBox(width: 10),
            //                 const Text(
            //                   'ประหยัดพลังงาน',
            //                   style: TextStyle(
            //                     fontSize: 18,
            //                     fontWeight: FontWeight.bold,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //             Switch(
            //               value: _motionBasedEnabled,
            //               onChanged: _toggleMotionBasedDetection,
            //               activeColor: Colors.green,
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 8),
            //         const Text(
            //             'เมื่อเปิดใช้งาน แอปจะตรวจจับเฉพาะเมื่อมีการเคลื่อนไหวเท่านั้น เพื่อประหยัดแบตเตอรี่'),
            //       ],
            //     ),
            //   ),
            // ),

            const SizedBox(height: 16),

            // ข้อมูลติดต่อฉุกเฉิน
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child:
            //     Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           children: [
            //             const Icon(Icons.contact_phone, color: Colors.purple),
            //             const SizedBox(width: 10),
            //             const Text(
            //               'ข้อมูลติดต่อฉุกเฉิน',
            //               style: TextStyle(
            //                 fontSize: 18,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 16),
            //         ListTile(
            //           title: const Text('ชื่อผู้ติดต่อ'),
            //           subtitle: Text(_emergencyContact),
            //           trailing: const Icon(Icons.arrow_forward_ios),
            //           onTap: _openSettings,
            //         ),
            //         const Divider(),
            //         ListTile(
            //           title: const Text('เบอร์โทรศัพท์'),
            //           subtitle: Text(_emergencyPhone.isEmpty
            //               ? 'ยังไม่ได้ตั้งค่า'
            //               : _emergencyPhone),
            //           trailing: const Icon(Icons.arrow_forward_ios),
            //           onTap: _openSettings,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ส่วนแสดงค่าเซ็นเซอร์ปัจจุบัน
                const Text(
                  'ค่าเซ็นเซอร์ปัจจุบัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // แสดงค่าเซ็นเซอร์ต่างๆ
                Row(
                  children: [
                    Expanded(
                      child: SensorDataDisplay(
                        label: 'Acceleration',
                        value: _currentSensorData['acceleration']
                                ?.toStringAsFixed(2) ??
                            '0.00',
                        unit: 'm/s²',
                        icon: Icons.speed,
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: SensorDataDisplay(
                        label: 'Height',
                        value: _currentSensorData['barometer_height']
                                ?.toStringAsFixed(2) ??
                            '0.00',
                        unit: 'm',
                        icon: Icons.height,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: SensorDataDisplay(
                        label: 'Speed',
                        value: _currentSensorData['crash_speed']
                                ?.toStringAsFixed(1) ??
                            '0.0',
                        unit: 'km/h',
                        icon: Icons.directions_car,
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: SensorDataDisplay(
                        label: 'Rotation',
                        value: _currentSensorData['crash_rotation']
                                ?.toStringAsFixed(2) ??
                            '0.00',
                        unit: 'rad/s',
                        icon: Icons.rotate_right,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ปุ่มทดสอบการแจ้งเตือน
                const Text(
                  'ทดสอบการแจ้งเตือน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // คำแนะนำสำหรับการทดสอบ
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คำแนะนำสำหรับการทดสอบ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. ทดสอบการล้ม: ถือโทรศัพท์แล้วปล่อยตกลงบนเบาะหรือที่นอน (ระวังไม่ให้โทรศัพท์เสียหาย)',
                        ),
                        SizedBox(height: 4),
                        Text(
                          '2. ทดสอบการชน: ทำการเคลื่อนไหวโทรศัพท์อย่างรวดเร็วแล้วหยุดกะทันหัน',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _testFallDetection,
                    icon: const Icon(Icons.elderly),
                    label: const Text('ทดสอบการแจ้งเตือนการล้ม'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _testCrashDetection,
                    icon: const Icon(Icons.car_crash),
                    label: const Text('ทดสอบการแจ้งเตือนการชน'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

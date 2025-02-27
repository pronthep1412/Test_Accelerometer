import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:vibration/vibration.dart';
// import 'package:wakelock/wakelock.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertScreen extends StatefulWidget {
  final String alertType; // 'fall' หรือ 'crash'
  final Map<String, dynamic> eventData;

  const AlertScreen({
    super.key,
    required this.alertType,
    required this.eventData,
  });

  @override
  _AlertScreenState createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  // สถานะนับถอยหลัง
  int _countdown = 30;
  bool _isCountingDown = true;
  late Timer _countdownTimer;

  // ข้อมูลผู้ติดต่อฉุกเฉิน
  String _primaryContactName = '';
  String _primaryContactPhone = '';

  // ข้อมูลเกี่ยวกับ GPS
  String _locationString = 'กำลังโหลดพิกัด...';

  @override
  void initState() {
    super.initState();

    // เปิด Wake Lock ให้หน้าจอไม่ดับระหว่างแจ้งเตือน
    // Wakelock.enable();

    // โหลดข้อมูลผู้ติดต่อฉุกเฉิน
    _loadEmergencyContacts();

    // ตั้งค่าเวลานับถอยหลังตามประเภทการแจ้งเตือน
    _loadCountdownSettings();

    // จัดรูปแบบข้อมูลตำแหน่ง GPS
    _formatLocationString();

    // เริ่มสั่นและเสียงเตือน
    _startAlerts();

    // เริ่มนับถอยหลัง
    _startCountdown();
  }

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _primaryContactName =
          prefs.getString('emergency_contact_name') ?? 'ผู้ติดต่อฉุกเฉิน';
      _primaryContactPhone = prefs.getString('emergency_contact_phone') ?? '';
    });
  }

  Future<void> _loadCountdownSettings() async {
    final prefs = await SharedPreferences.getInstance();
    int defaultCountdown;

    if (widget.alertType == 'fall') {
      defaultCountdown = prefs.getInt('fall_countdown_seconds') ?? 30;
    } else {
      // crash
      defaultCountdown = prefs.getInt('crash_countdown_seconds') ?? 20;
    }

    setState(() {
      _countdown = defaultCountdown;
    });
  }

  void _formatLocationString() {
    if (widget.eventData.containsKey('location') &&
        widget.eventData['location'] != null) {
      final location = widget.eventData['location'];
      if (location is Map &&
          location.containsKey('latitude') &&
          location.containsKey('longitude')) {
        final lat = location['latitude'];
        final lng = location['longitude'];
        setState(() {
          _locationString = 'พิกัด: $lat, $lng';
        });
      }
    }
  }

  void _startAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    final soundEnabled = prefs.getBool('sound_alert_enabled') ?? true;

    // if (vibrationEnabled) {
    //   // ตรวจสอบว่าอุปกรณ์รองรับการสั่นหรือไม่
    //   bool? hasVibrator = await Vibration.hasVibrator();
    //   if (hasVibrator == true) {
    //     try {
    //       // สั่นแบบรูปแบบ SOS - ต้องมีจำนวนเลขคู่
    //       Vibration.vibrate(
    //         pattern: [
    //           500,
    //           1000,
    //           500,
    //           1000,
    //           500,
    //           1000,
    //           500,
    //           1000
    //         ], // เพิ่ม 1000 ตัวสุดท้ายให้ครบเลขคู่
    //         repeat: 1,
    //       );
    //     } catch (e) {
    //       print("Vibration error: $e");
    //     }
    //   }
    // }

    // เพิ่ม code สำหรับเล่นเสียงเตือน
    if (soundEnabled) {
      // เล่นเสียงเตือน
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _isCountingDown = false;
          timer.cancel();
          _handleTimeOut();
        }
      });
    });
  }

  void _handleTimeOut() {
    // ส่งข้อความอัตโนมัติ เมื่อหมดเวลา
    _sendEmergencyMessage();
  }

  Future<void> _sendEmergencyMessage() async {
    // ถ้ามีเบอร์โทรศัพท์ผู้ติดต่อฉุกเฉิน
    if (_primaryContactPhone.isNotEmpty) {
      final String alertTypeLabel =
          widget.alertType == 'fall' ? 'การล้ม' : 'การชน';

      // ข้อความที่จะส่ง
      String message = 'ฉุกเฉิน! ตรวจพบ$alertTypeLabel';

      // เพิ่มพิกัดถ้ามี
      if (widget.eventData.containsKey('location')) {
        final location = widget.eventData['location'];
        if (location != null &&
            location is Map &&
            location.containsKey('latitude') &&
            location.containsKey('longitude')) {
          final lat = location['latitude'];
          final lng = location['longitude'];
          message += ' ที่พิกัด: https://maps.google.com/maps?q=$lat,$lng';
        }
      }

      // ลิงก์สำหรับส่ง SMS
      final Uri smsUri = Uri.parse(
          'sms:$_primaryContactPhone?body=${Uri.encodeComponent(message)}');

      try {
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        }
      } catch (e) {
        print('Error sending SMS: $e');
      }
    }
  }

  Future<void> _callEmergencyContact() async {
    if (_primaryContactPhone.isNotEmpty) {
      final Uri callUri = Uri.parse('tel:$_primaryContactPhone');

      try {
        if (await canLaunchUrl(callUri)) {
          await launchUrl(callUri);
        }
      } catch (e) {
        print('Error making call: $e');
      }
    }
  }

  void _cancelAlert() {
    // หยุดการสั่น
    // Vibration.cancel();

    // หยุดการนับถอยหลัง
    _countdownTimer.cancel();

    // ปิด Wakelock
    // Wakelock.disable();

    // ย้อนกลับไปหน้าก่อนหน้า
    Navigator.pop(context);
  }

  String _getAlertTitle() {
    if (widget.alertType == 'fall') {
      return 'ตรวจพบการล้ม!';
    } else {
      return 'ตรวจพบการชน!';
    }
  }

  @override
  void dispose() {
    try {
      _countdownTimer.cancel();
      // Vibration.cancel();
      // Wakelock.disable();
    } catch (e) {
      print('Error in dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text(_getAlertTitle()),
        backgroundColor: Colors.red,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ส่วนแจ้งเตือน
            Container(
              color: Colors.red,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isCountingDown
                        ? 'จะส่งการแจ้งเตือนฉุกเฉินใน $_countdown วินาที'
                        : 'ได้ส่งการแจ้งเตือนฉุกเฉินแล้ว',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลเหตุการณ์
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'รายละเอียดเหตุการณ์',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            _buildEventInfoItem(
                              'ประเภท',
                              widget.alertType == 'fall' ? 'การล้ม' : 'การชน',
                              Icons.info,
                            ),
                            _buildEventInfoItem(
                              'เวลา',
                              _formatTimestamp(widget.eventData['timestamp']),
                              Icons.access_time,
                            ),
                            if (widget.alertType == 'crash' &&
                                widget.eventData.containsKey('speed'))
                              _buildEventInfoItem(
                                'ความเร็ว',
                                '${widget.eventData['speed'].toStringAsFixed(1)} กม./ชม.',
                                Icons.speed,
                              ),
                            _buildEventInfoItem(
                              'ตำแหน่ง',
                              _locationString,
                              Icons.location_on,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ข้อมูลผู้ติดต่อฉุกเฉิน
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ผู้ติดต่อฉุกเฉิน',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            ListTile(
                              title: Text(_primaryContactName),
                              subtitle: Text(_primaryContactPhone.isEmpty
                                  ? 'ไม่ได้ตั้งค่าเบอร์โทรศัพท์'
                                  : _primaryContactPhone),
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              trailing: _primaryContactPhone.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.call,
                                          color: Colors.green),
                                      onPressed: _callEmergencyContact,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ปุ่มดำเนินการ
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _sendEmergencyMessage,
                      icon: const Icon(Icons.message),
                      label: const Text('ส่งข้อความแจ้งเตือนทันที'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _cancelAlert,
                      icon: const Icon(Icons.cancel),
                      label: const Text('ยกเลิกการแจ้งเตือน'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.red),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'ไม่ทราบ';

    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }
}

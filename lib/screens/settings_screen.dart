import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/detection/detection_manager.dart';
import 'emergency_contacts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DetectionManager _detectionManager = DetectionManager();

  // การตั้งค่าความไว
  String _fallSensitivity = 'medium';
  String _crashSensitivity = 'medium';
  String _motionSensitivity = 'medium';

  // การตั้งค่าการเริ่มต้นอัตโนมัติ
  bool _autoStartOnBoot = false;
  bool _runInBackground = false;

  // การตั้งค่าการแจ้งเตือน
  bool _vibrationEnabled = true;
  bool _soundAlertEnabled = true;
  int _fallCountdownSeconds = 30;
  int _crashCountdownSeconds = 20;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // โหลดการตั้งค่าความไว
      _fallSensitivity =
          prefs.getString('fall_detection_sensitivity') ?? 'medium';
      _crashSensitivity =
          prefs.getString('crash_detection_sensitivity') ?? 'medium';
      _motionSensitivity =
          prefs.getString('motion_detection_sensitivity') ?? 'medium';

      // โหลดการตั้งค่าการเริ่มต้นอัตโนมัติ
      _autoStartOnBoot = prefs.getBool('auto_start_on_boot') ?? false;
      _runInBackground = prefs.getBool('run_in_background') ?? true;

      // โหลดการตั้งค่าการแจ้งเตือน
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _soundAlertEnabled = prefs.getBool('sound_alert_enabled') ?? true;
      _fallCountdownSeconds = prefs.getInt('fall_countdown_seconds') ?? 30;
      _crashCountdownSeconds = prefs.getInt('crash_countdown_seconds') ?? 20;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _changeFallSensitivity(String? value) async {
    if (value == null) return;

    setState(() {
      _fallSensitivity = value;
    });

    await _detectionManager.setFallDetectionSensitivity(value);
    await _saveSetting('fall_detection_sensitivity', value);
  }

  Future<void> _changeCrashSensitivity(String? value) async {
    if (value == null) return;

    setState(() {
      _crashSensitivity = value;
    });

    await _detectionManager.setCrashDetectionSensitivity(value);
    await _saveSetting('crash_detection_sensitivity', value);
  }

  Future<void> _changeMotionSensitivity(String? value) async {
    if (value == null) return;

    setState(() {
      _motionSensitivity = value;
    });

    await _detectionManager.setMotionDetectionSensitivity(value);
    await _saveSetting('motion_detection_sensitivity', value);
  }

  Future<void> _toggleAutoStartOnBoot(bool value) async {
    setState(() {
      _autoStartOnBoot = value;
    });
    await _saveSetting('auto_start_on_boot', value);
  }

  Future<void> _toggleRunInBackground(bool value) async {
    setState(() {
      _runInBackground = value;
    });
    await _saveSetting('run_in_background', value);
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() {
      _vibrationEnabled = value;
    });
    await _saveSetting('vibration_enabled', value);
  }

  Future<void> _toggleSoundAlert(bool value) async {
    setState(() {
      _soundAlertEnabled = value;
    });
    await _saveSetting('sound_alert_enabled', value);
  }

  Future<void> _changeFallCountdown(int? value) async {
    if (value == null) return;

    setState(() {
      _fallCountdownSeconds = value;
    });
    await _saveSetting('fall_countdown_seconds', value);
  }

  Future<void> _changeCrashCountdown(int? value) async {
    if (value == null) return;

    setState(() {
      _crashCountdownSeconds = value;
    });
    await _saveSetting('crash_countdown_seconds', value);
  }

  void _goToEmergencyContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
    );
  }

  String _getSensitivityLabel(String value) {
    switch (value) {
      case 'high':
        return 'สูง (ไว)';
      case 'medium':
        return 'กลาง';
      case 'low':
        return 'ต่ำ (ไม่ไว)';
      default:
        return 'กลาง';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // หมวดการตั้งค่าความไว
            _buildSectionHeader('การตั้งค่าความไวในการตรวจจับ'),

            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('ความไวในการตรวจจับการล้ม'),
                    subtitle: Text(_getSensitivityLabel(_fallSensitivity)),
                    trailing: DropdownButton<String>(
                      value: _fallSensitivity,
                      onChanged: _changeFallSensitivity,
                      items: const [
                        DropdownMenuItem(
                            value: 'low', child: Text('ต่ำ (ไม่ไว)')),
                        DropdownMenuItem(value: 'medium', child: Text('กลาง')),
                        DropdownMenuItem(
                            value: 'high', child: Text('สูง (ไว)')),
                      ],
                      underline: Container(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('ความไวในการตรวจจับการชน'),
                    subtitle: Text(_getSensitivityLabel(_crashSensitivity)),
                    trailing: DropdownButton<String>(
                      value: _crashSensitivity,
                      onChanged: _changeCrashSensitivity,
                      items: const [
                        DropdownMenuItem(
                            value: 'low', child: Text('ต่ำ (ไม่ไว)')),
                        DropdownMenuItem(value: 'medium', child: Text('กลาง')),
                        DropdownMenuItem(
                            value: 'high', child: Text('สูง (ไว)')),
                      ],
                      underline: Container(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('ความไวในการตรวจจับการเคลื่อนไหว'),
                    subtitle: Text(_getSensitivityLabel(_motionSensitivity)),
                    trailing: DropdownButton<String>(
                      value: _motionSensitivity,
                      onChanged: _changeMotionSensitivity,
                      items: const [
                        DropdownMenuItem(
                            value: 'low', child: Text('ต่ำ (ไม่ไว)')),
                        DropdownMenuItem(value: 'medium', child: Text('กลาง')),
                        DropdownMenuItem(
                            value: 'high', child: Text('สูง (ไว)')),
                      ],
                      underline: Container(),
                    ),
                  ),
                ],
              ),
            ),

            // หมวดการตั้งค่าการทำงานเบื้องหลัง
            _buildSectionHeader('การตั้งค่าการทำงานเบื้องหลัง'),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('เริ่มทำงานอัตโนมัติหลังเปิดเครื่อง'),
                    subtitle: const Text(
                        'เปิดการตรวจจับโดยอัตโนมัติเมื่อเปิดเครื่อง'),
                    value: _autoStartOnBoot,
                    onChanged: _toggleAutoStartOnBoot,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('ทำงานในโหมดเบื้องหลัง'),
                    subtitle: const Text('ตรวจจับต่อเนื่องแม้ไม่ได้เปิดแอป'),
                    value: _runInBackground,
                    onChanged: _toggleRunInBackground,
                  ),
                ],
              ),
            ),

            // หมวดการตั้งค่าการแจ้งเตือน
            _buildSectionHeader('การตั้งค่าการแจ้งเตือน'),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('การสั่น'),
                    subtitle: const Text('สั่นเตือนเมื่อตรวจพบการล้มหรือการชน'),
                    value: _vibrationEnabled,
                    onChanged: _toggleVibration,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('เสียงเตือน'),
                    subtitle:
                        const Text('เล่นเสียงเตือนเมื่อตรวจพบการล้มหรือการชน'),
                    value: _soundAlertEnabled,
                    onChanged: _toggleSoundAlert,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('เวลานับถอยหลังสำหรับการล้ม (วินาที)'),
                    subtitle: Text('$_fallCountdownSeconds วินาที'),
                    trailing: DropdownButton<int>(
                      value: _fallCountdownSeconds,
                      onChanged: _changeFallCountdown,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 60, child: Text('60')),
                      ],
                      underline: Container(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('เวลานับถอยหลังสำหรับการชน (วินาที)'),
                    subtitle: Text('$_crashCountdownSeconds วินาที'),
                    trailing: DropdownButton<int>(
                      value: _crashCountdownSeconds,
                      onChanged: _changeCrashCountdown,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                      ],
                      underline: Container(),
                    ),
                  ),
                ],
              ),
            ),

            // ข้อมูลผู้ติดต่อฉุกเฉิน
            _buildSectionHeader('ข้อมูลผู้ติดต่อฉุกเฉิน'),

            Card(
              child: ListTile(
                leading: const Icon(Icons.contacts, color: Colors.purple),
                title: const Text('จัดการผู้ติดต่อฉุกเฉิน'),
                subtitle:
                    const Text('เพิ่มหรือแก้ไขรายชื่อผู้ติดต่อในกรณีฉุกเฉิน'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _goToEmergencyContacts,
              ),
            ),

            const SizedBox(height: 16),

            // รีเซ็ตการตั้งค่า
            Center(
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('รีเซ็ตการตั้งค่า'),
                      content: const Text(
                          'คุณต้องการรีเซ็ตการตั้งค่าทั้งหมดเป็นค่าเริ่มต้นหรือไม่?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ยกเลิก'),
                        ),
                        TextButton(
                          onPressed: () {
                            // รีเซ็ตการตั้งค่า
                            Navigator.pop(context);
                            _loadSettings();
                          },
                          child: const Text('รีเซ็ต'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restore, color: Colors.red),
                label: const Text('รีเซ็ตการตั้งค่าทั้งหมด',
                    style: TextStyle(color: Colors.red)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

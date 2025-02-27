import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class EmergencyAlertDialog extends StatefulWidget {
  final String title;
  final String message;
  final Map<String, dynamic> eventData;
  final String emergencyContact;
  final String emergencyPhone;
  final VoidCallback onFalseAlarm;
  final VoidCallback onEmergencyCall;
  final int countdownSeconds;
  final VoidCallback onCountdownFinished;

  const EmergencyAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.eventData,
    required this.emergencyContact,
    required this.emergencyPhone,
    required this.onFalseAlarm,
    required this.onEmergencyCall,
    required this.countdownSeconds,
    required this.onCountdownFinished,
  });

  @override
  _EmergencyAlertDialogState createState() => _EmergencyAlertDialogState();
}

class _EmergencyAlertDialogState extends State<EmergencyAlertDialog>
    with SingleTickerProviderStateMixin {
  late int _countdown;
  late Timer _countdownTimer;
  bool _isEmergencyCallInProgress = false;

  // สำหรับ animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdownSeconds;

    // ตั้งค่า animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // เริ่ม animation
    _animationController.forward();

    // เริ่มการนับถอยหลัง
    _startCountdown();

    // สั่นเตือน
    _startVibration();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
          widget.onCountdownFinished();
        }
      });
    });
  }

  void _startVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [500, 1000, 500, 1000, 500, 1000, 500, 1000],
        intensities: [128, 255, 128, 255, 128],
      );
    }
  }

  void _handleFalseAlarm() {
    // หยุดการสั่น
    Vibration.cancel();

    // หยุดการนับถอยหลัง
    _countdownTimer.cancel();

    // เรียกการ callback
    widget.onFalseAlarm();
  }

  void _handleEmergencyCall() {
    setState(() {
      _isEmergencyCallInProgress = true;
    });

    // หยุดการสั่น
    Vibration.cancel();

    // หยุดการนับถอยหลัง
    _countdownTimer.cancel();

    // เรียกการ callback
    widget.onEmergencyCall();
  }

  String _formatEventType() {
    final type = widget.eventData['type'];

    if (type == 'fall') {
      return 'การล้ม';
    } else if (type == 'crash') {
      return 'การชน';
    } else {
      return 'เหตุการณ์';
    }
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _animationController.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: AlertDialog(
              title: Column(
                children: [
                  Icon(
                    widget.title.contains('ล้ม')
                        ? Icons.elderly
                        : Icons.car_crash,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    value: _countdown / widget.countdownSeconds,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'จะส่งการแจ้งเตือนฉุกเฉินใน $_countdown วินาที',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ข้อมูลผู้ติดต่อฉุกเฉิน:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ชื่อ: ${widget.emergencyContact}',
                        ),
                        if (widget.emergencyPhone.isNotEmpty)
                          Text(
                            'เบอร์โทร: ${widget.emergencyPhone}',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      _isEmergencyCallInProgress ? null : _handleFalseAlarm,
                  child: const Text(
                    'ยกเลิกการแจ้งเตือน',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed:
                      _isEmergencyCallInProgress ? null : _handleEmergencyCall,
                  icon: const Icon(Icons.call),
                  label: const Text('ขอความช่วยเหลือเดี๋ยวนี้'),
                ),
              ],
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MotionDetectionService {
  // ค่า threshold สำหรับการตรวจจับการเคลื่อนไหว
  double _motionThreshold = 1.2; // ความเร่งขั้นต่ำที่ถือว่ามีการเคลื่อนไหว
  static const int MOTION_WINDOW_SIZE =
      10; // จำนวนตัวอย่างสำหรับตรวจการเคลื่อนไหว
  static const int INACTIVE_THRESHOLD_MS =
      10000; // เวลาไม่เคลื่อนไหวก่อนเข้าสู่โหมดประหยัดพลังงาน (10 วินาที)

  bool _isMonitoring = false;
  bool _isActive = false; // สถานะการเคลื่อนไหว
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _inactiveTimer;
  DateTime _lastActiveTime = DateTime.now();

  // สำหรับเก็บข้อมูลความเร่งเพื่อวิเคราะห์
  List<double> _accelerationValues = [];

  // ค่าล่าสุด
  double _lastAcceleration = 0.0;

  // ฟังก์ชันที่จะเรียกเมื่อสถานะการเคลื่อนไหวเปลี่ยน
  final Function(bool)? onMotionStateChanged;

  MotionDetectionService({this.onMotionStateChanged});

  bool get isMonitoring => _isMonitoring;
  bool get isActive => _isActive;
  double get lastAcceleration => _lastAcceleration;

  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _accelerationValues = [];
    _lastActiveTime = DateTime.now();

    // เริ่มอ่านข้อมูลจาก accelerometer ที่ความถี่ต่ำ (ประหยัดพลังงาน)
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });

    // ตั้งเวลาสำหรับตรวจสอบความไม่เคลื่อนไหว
    _startInactiveTimer();

    print("Motion detection monitoring started");
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelerometerSubscription?.cancel();
    _inactiveTimer?.cancel();
    print("Motion detection monitoring stopped");
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // คำนวณความเร่งรวม (magnitude) จากแกน x, y, z
    double magnitude =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // หักแรงโน้มถ่วงโลก (ประมาณ 9.8 m/s²)
    magnitude = (magnitude - 9.8).abs();
    _lastAcceleration = magnitude;

    // เก็บข้อมูลสำหรับวิเคราะห์
    _accelerationValues.add(magnitude);

    // เก็บเฉพาะข้อมูลล่าสุด MOTION_WINDOW_SIZE ค่า
    if (_accelerationValues.length > MOTION_WINDOW_SIZE) {
      _accelerationValues.removeAt(0);
    }

    // วิเคราะห์การเคลื่อนไหว
    _analyzeMotion();
  }

  void _analyzeMotion() {
    if (_accelerationValues.length < MOTION_WINDOW_SIZE) return;

    // หาค่า max ในช่วงเวลาที่ผ่านมา
    double maxAcceleration = _accelerationValues.reduce(max);

    // ตรวจสอบว่ามีการเคลื่อนไหวหรือไม่
    bool hasMotion = maxAcceleration > _motionThreshold;

    if (hasMotion) {
      // มีการเคลื่อนไหว
      _lastActiveTime = DateTime.now();

      if (!_isActive) {
        // เปลี่ยนสถานะจากไม่เคลื่อนไหวเป็นเคลื่อนไหว
        _isActive = true;
        onMotionStateChanged?.call(true);
        print("Motion detected: Active state");
      }
    } else {
      // ตรวจสอบว่าไม่มีการเคลื่อนไหวนานเกินกำหนดหรือไม่
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastActiveTime).inMilliseconds;

      if (_isActive && elapsedMs > INACTIVE_THRESHOLD_MS) {
        // เปลี่ยนสถานะจากเคลื่อนไหวเป็นไม่เคลื่อนไหว
        _isActive = false;
        onMotionStateChanged?.call(false);
        print("No motion detected: Inactive state");
      }
    }
  }

  void _startInactiveTimer() {
    _inactiveTimer?.cancel();
    _inactiveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastActiveTime).inMilliseconds;

      if (_isActive && elapsedMs > INACTIVE_THRESHOLD_MS) {
        _isActive = false;
        onMotionStateChanged?.call(false);
        print("Inactive timer: No motion detected");
      }
    });
  }

  // ปรับการตั้งค่าความไวในการตรวจจับการเคลื่อนไหว
  Future<void> setSensitivity(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('motion_detection_sensitivity', level);

    switch (level) {
      case 'high':
        // ไวมาก - ตรวจจับการเคลื่อนไหวเล็กน้อย
        _motionThreshold = 0.8;
        break;
      case 'medium':
        // ค่ากลาง
        _motionThreshold = 1.2;
        break;
      case 'low':
        // ไวน้อย - ต้องเคลื่อนไหวชัดเจน
        _motionThreshold = 1.8;
        break;
      default:
        _motionThreshold = 1.2;
    }
  }

  // โหลดการตั้งค่าความไว
  Future<void> loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    String level = prefs.getString('motion_detection_sensitivity') ?? 'medium';
    await setSensitivity(level);
  }
}

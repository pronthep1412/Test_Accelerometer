import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashDetectionService {
  // ค่า threshold สำหรับการตรวจจับการชน
  double _crashThreshold = 50.0; // G-forces ที่บ่งบอกการชน
  final int _highImpactDurationThreshold = 100; // มิลลิวินาที
  double _rotationThreshold = 3.0; // ค่าการหมุนรวม (rad/s) ที่บ่งบอกการพลิกคว่ำ

  bool _isMonitoring = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _locationSubscription;

  // สำหรับเก็บข้อมูลความเร่งและการหมุน
  List<double> _accelerationValues = [];
  List<double> _rotationValues = [];

  // เก็บข้อมูลตำแหน่ง
  Position? _lastKnownPosition;

  // เก็บข้อมูลความเร็ว (คำนวณจากตำแหน่ง)
  double _lastSpeed = 0.0;
  DateTime? _lastSpeedUpdate;
  DateTime? _lastLocationUpdate;

  // เก็บข้อมูลความเร่งล่าสุด
  double _lastAcceleration = 0.0;
  double _lastRotation = 0.0;

  // ฟังก์ชันที่จะเรียกเมื่อตรวจพบการชน
  final Function(Map<String, dynamic>)? onCrashDetected;

  // ฟังก์ชันที่จะเรียกเมื่อมีการยกเลิกการแจ้งเตือน
  final VoidCallback? onFalseAlarm;

  CrashDetectionService({this.onCrashDetected, this.onFalseAlarm});

  bool get isMonitoring => _isMonitoring;
  Position? get lastPosition => _lastKnownPosition;
  double get lastSpeed => _lastSpeed;
  double get lastAcceleration => _lastAcceleration;
  double get lastRotation => _lastRotation;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    // ขอสิทธิ์ location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isMonitoring = true;
    _accelerationValues = [];
    _rotationValues = [];

    // เริ่มเก็บข้อมูล accelerometer
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });

    // เริ่มเก็บข้อมูล gyroscope
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _processGyroscopeData(event);
    });

    // เริ่มเก็บข้อมูลตำแหน่ง
    _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // อัพเดททุก 5 เมตร
    )).listen((Position position) {
      _processLocationData(position);
    });

    print("Crash detection monitoring started");
    return Future.value();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _locationSubscription?.cancel();
    print("Crash detection monitoring stopped");
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // คำนวณความเร่งรวม (magnitude)
    double magnitude =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // หักแรงโน้มถ่วงโลก (ประมาณ 9.8 m/s²)
    magnitude = (magnitude - 9.8).abs();
    _lastAcceleration = magnitude;

    // เก็บข้อมูลสำหรับวิเคราะห์
    _accelerationValues.add(magnitude);

    // เก็บเฉพาะข้อมูลล่าสุด 50 ค่า (ประมาณ 2.5 วินาที ถ้าอ่านที่ 20Hz)
    if (_accelerationValues.length > 50) {
      _accelerationValues.removeAt(0);
    }

    // ตรวจสอบการชน
    _analyzeCrashData();
  }

  void _processGyroscopeData(GyroscopeEvent event) {
    // คำนวณการหมุนรวม
    double rotationMagnitude =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
    _lastRotation = rotationMagnitude;

    // เก็บข้อมูลสำหรับวิเคราะห์
    _rotationValues.add(rotationMagnitude);

    // เก็บเฉพาะข้อมูลล่าสุด 50 ค่า
    if (_rotationValues.length > 50) {
      _rotationValues.removeAt(0);
    }
  }

  void _processLocationData(Position position) {
    // เก็บตำแหน่งล่าสุด
    Position? previousPosition = _lastKnownPosition;
    _lastKnownPosition = position;
    DateTime now = DateTime.now();

    // คำนวณความเร็ว (เมตร/วินาที)
    if (previousPosition != null && _lastLocationUpdate != null) {
      double distanceInMeters = Geolocator.distanceBetween(
          previousPosition.latitude,
          previousPosition.longitude,
          position.latitude,
          position.longitude);

      double timeInSeconds =
          now.difference(_lastLocationUpdate!).inMilliseconds / 1000;
      if (timeInSeconds > 0) {
        _lastSpeed = distanceInMeters / timeInSeconds;
        _lastSpeedUpdate = now;
      }
    }

    _lastLocationUpdate = now;
  }

  void _analyzeCrashData() {
    if (_accelerationValues.length < 10) return; // ต้องมีข้อมูลพอ

    // ตรวจสอบการชนจากความเร่ง
    double maxAcceleration = _accelerationValues.reduce(max);

    // ตรวจสอบการชนเมื่อความเร่งสูงและความเร็วก่อนหน้านี้สูงพอ
    if (maxAcceleration > _crashThreshold && _lastSpeed > 5.0) {
      // ความเร็วมากกว่า 5 เมตร/วินาที (18 กม./ชม.)
      _checkCrashPattern();
    }
  }

  void _checkCrashPattern() {
    // ตรวจสอบรูปแบบการชน:
    // 1. ความเร่งสูงฉับพลัน
    // 2. ตามด้วยการเปลี่ยนทิศทางการหมุนอย่างรวดเร็ว
    // 3. ตามด้วยความเร่งต่ำ (หยุดนิ่ง)

    // ตรวจสอบระยะเวลาของความเร่งสูง
    int highImpactDuration = 0;
    for (int i = _accelerationValues.length - 1; i >= 0; i--) {
      if (_accelerationValues[i] > _crashThreshold / 2) {
        highImpactDuration++;
      } else {
        break;
      }
    }

    // ตรวจสอบว่ามีการเปลี่ยนแปลงการหมุนเร็วๆ นี้
    double maxRotation = 0;
    if (_rotationValues.isNotEmpty) {
      maxRotation = _rotationValues.reduce(max);
    }

    // ตรวจสอบว่าหลังความเร่งสูงแล้วกลับมานิ่ง
    List<double> recentAccValues =
        _accelerationValues.reversed.take(5).toList();
    double avgRecentAcc =
        recentAccValues.reduce((a, b) => a + b) / recentAccValues.length;

    // เงื่อนไขการตัดสินว่าเกิดการชน
    if (highImpactDuration > 3 && // ความเร่งสูงนานพอ
        highImpactDuration < _highImpactDurationThreshold && // แต่ไม่นานเกินไป
        maxRotation > _rotationThreshold && // มีการหมุนรวดเร็ว
        avgRecentAcc < 5.0) {
      // ตามด้วยความนิ่ง

      _handleCrashDetection(maxRotation, avgRecentAcc);
    }
  }

  void _handleCrashDetection(double maxRotation, double avgRecentAcc) {
    print("CRASH DETECTED!");

    // สั่นเตือน
    Vibration.vibrate(duration: 2000);

    // รวบรวมข้อมูลเกี่ยวกับการชน
    Map<String, dynamic> crashData = {
      'timestamp': DateTime.now().toIso8601String(),
      'location': _lastKnownPosition != null
          ? {
              'latitude': _lastKnownPosition!.latitude,
              'longitude': _lastKnownPosition!.longitude,
            }
          : null,
      'speed': _lastSpeed * 3.6, // แปลงเป็น km/h
      'impact_force':
          _accelerationValues.isNotEmpty ? _accelerationValues.reduce(max) : 0,
      'rotation': maxRotation,
      'post_crash_movement': avgRecentAcc,
      'type': 'crash',
    };

    // เรียกฟังก์ชันที่ส่งมาจากข้างนอก
    onCrashDetected?.call(crashData);

    // หยุดการตรวจจับชั่วคราว
    _resetDetection();
  }

  void _resetDetection() {
    // รีเซ็ตข้อมูลสำหรับการตรวจจับครั้งต่อไป
    _accelerationValues.clear();
    _rotationValues.clear();
  }

  void cancelCrashAlert() {
    // เรียกเมื่อผู้ใช้ยกเลิกการแจ้งเตือน
    onFalseAlarm?.call();
  }

  // บันทึกการตั้งค่าความไวของการตรวจจับ
  Future<void> setSensitivity(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crash_detection_sensitivity', level);

    // ปรับค่า threshold ตามระดับความไว
    switch (level) {
      case 'high':
        // ไวมาก - ตรวจจับง่าย
        _crashThreshold = 40.0;
        _rotationThreshold = 2.5;
        break;
      case 'medium':
        // ค่ากลาง
        _crashThreshold = 50.0;
        _rotationThreshold = 3.0;
        break;
      case 'low':
        // ไวน้อย
        _crashThreshold = 60.0;
        _rotationThreshold = 3.5;
        break;
    }
  }

  // โหลดการตั้งค่าความไว
  Future<void> loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    String level = prefs.getString('crash_detection_sensitivity') ?? 'medium';
    await setSensitivity(level);
  }
}

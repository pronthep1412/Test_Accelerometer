import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// ยูทิลิตี้สำหรับประมวลผลข้อมูลจากเซ็นเซอร์
class SensorUtils {
  /// คำนวณความเร่งรวม (magnitude) จากข้อมูล accelerometer ในแกน x, y, z
  static double calculateAccelerationMagnitude(AccelerometerEvent event) {
    return sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
  }

  /// คำนวณความเร่งรวม โดยหักค่าแรงโน้มถ่วงโลก (9.8 m/s²)
  static double calculateAccelerationWithoutGravity(AccelerometerEvent event) {
    final magnitude = calculateAccelerationMagnitude(event);
    return (magnitude - 9.8).abs();
  }

  /// คำนวณการหมุนรวม (magnitude) จากข้อมูล gyroscope ในแกน x, y, z
  static double calculateRotationMagnitude(GyroscopeEvent event) {
    return sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
  }

  /// คำนวณความสูงจากความกดอากาศ
  ///
  /// สูตร: h = 44330 * (1 - (p/p0)^0.19)
  /// โดย:
  /// - h = ความสูง (เมตร)
  /// - p = ความกดอากาศที่ระดับปัจจุบัน (hPa)
  /// - p0 = ความกดอากาศที่ระดับน้ำทะเล (1013.25 hPa)
  static double calculateHeightFromPressure(double pressure) {
    const double pressureAtSeaLevel = 1013.25; // hPa
    return 44330 * (1 - (pow(pressure / pressureAtSeaLevel, 0.19)).toDouble());
  }

  /// คำนวณความกดอากาศจากความสูง
  ///
  /// สูตร: p = p0 * (1 - h/44330)^5.255
  /// โดย:
  /// - p = ความกดอากาศที่ระดับปัจจุบัน (hPa)
  /// - h = ความสูง (เมตร)
  /// - p0 = ความกดอากาศที่ระดับน้ำทะเล (1013.25 hPa)
  static double calculatePressureFromHeight(double height) {
    const double pressureAtSeaLevel = 1013.25; // hPa
    return pressureAtSeaLevel * pow(1 - height / 44330, 5.255);
  }

  /// คำนวณการเปลี่ยนแปลงความสูงจากการเปลี่ยนแปลงความกดอากาศ
  ///
  /// สูตรโดยประมาณ: 1 hPa = 8.43 เมตร (ที่ระดับความสูงต่ำ)
  static double calculateHeightChangeFromPressure(
      double initialPressure, double finalPressure) {
    // เครื่องหมายลบเพราะความกดอากาศลดลงเมื่อระดับความสูงเพิ่มขึ้น
    return -8.43 * (finalPressure - initialPressure);
  }

  /// คำนวณค่าเฉลี่ยของข้อมูลในรายการ
  static double calculateAverage(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// คำนวณค่าสูงสุดของข้อมูลในรายการ
  static double calculateMax(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce(max);
  }

  /// คำนวณค่าต่ำสุดของข้อมูลในรายการ
  static double calculateMin(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce(min);
  }

  /// คำนวณส่วนเบี่ยงเบนมาตรฐานของข้อมูลในรายการ
  static double calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0;

    final avg = calculateAverage(values);
    final sumSquaredDiff = values.fold<double>(
      0,
      (sum, value) => sum + pow(value - avg, 2),
    );

    return sqrt(sumSquaredDiff / values.length);
  }

  /// ตรวจสอบว่าชุดข้อมูลมีการเปลี่ยนแปลงอย่างมีนัยสำคัญหรือไม่
  ///
  /// โดยใช้เกณฑ์:
  /// - ค่าส่วนเบี่ยงเบนมาตรฐานสูงกว่า threshold
  /// - ค่าต่างระหว่างค่าสูงสุดและค่าต่ำสุดสูงกว่า threshold
  static bool hasSignificantChange(List<double> values, double threshold) {
    if (values.length < 3) return false;

    final stdDev = calculateStandardDeviation(values);

    if (stdDev > threshold) return true;

    final maxValue = calculateMax(values);
    final minValue = calculateMin(values);

    return (maxValue - minValue) > threshold;
  }

  /// คำนวณความเร็วการเคลื่อนที่จากข้อมูล GPS
  static double calculateSpeedFromGPS(double lat1, double lon1, double lat2,
      double lon2, double timeInSeconds) {
    if (timeInSeconds <= 0) return 0;

    // คำนวณระยะทางระหว่างจุดที่ 1 และจุดที่ 2 (สูตร Haversine)
    const double earthRadius = 6371000; // รัศมีโลกในหน่วยเมตร

    final double lat1Rad = lat1 * pi / 180;
    final double lat2Rad = lat2 * pi / 180;
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c; // ระยะทางในหน่วยเมตร

    // คำนวณความเร็ว (เมตร/วินาที)
    return distance / timeInSeconds;
  }

  /// คำนวณความชันของกราฟเซ็นเซอร์
  static double calculateSlope(List<double> values, List<double> times) {
    if (values.length < 2 || values.length != times.length) return 0;

    // คำนวณโดยใช้สูตร slope = Σ((x - xMean)(y - yMean)) / Σ((x - xMean)²)
    final double xMean = calculateAverage(times);
    final double yMean = calculateAverage(values);

    double numerator = 0;
    double denominator = 0;

    for (int i = 0; i < values.length; i++) {
      final double xDiff = times[i] - xMean;
      final double yDiff = values[i] - yMean;

      numerator += xDiff * yDiff;
      denominator += xDiff * xDiff;
    }

    if (denominator.abs() < 0.0001) return 0; // ป้องกันการหารด้วยศูนย์

    return numerator / denominator;
  }

  /// บอกทิศทางของเซ็นเซอร์
  static String getSensorTrend(List<double> values) {
    if (values.length < 5) return 'ไม่ระบุ';

    final first = values.sublist(0, values.length ~/ 2);
    final second = values.sublist(values.length ~/ 2);

    final firstAvg = calculateAverage(first);
    final secondAvg = calculateAverage(second);

    final diff = secondAvg - firstAvg;

    if (diff > 1.5) {
      return 'เพิ่มขึ้นอย่างรวดเร็ว';
    } else if (diff > 0.5) {
      return 'เพิ่มขึ้น';
    } else if (diff < -1.5) {
      return 'ลดลงอย่างรวดเร็ว';
    } else if (diff < -0.5) {
      return 'ลดลง';
    } else {
      return 'คงที่';
    }
  }
}

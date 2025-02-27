import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:charts_flutter/flutter.dart' as charts;
import '../services/detection/detection_manager.dart';
import '../widgets/sensor_data_display.dart';
import 'alert_screen.dart';

class SensorReading {
  final double time;
  final double value;

  SensorReading({required this.time, required this.value});
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DetectionManager _detectionManager = DetectionManager();

  // สำหรับเก็บข้อมูลเซ็นเซอร์
  final List<SensorReading> _accelerationReadings = [];
  final List<SensorReading> _heightReadings = [];

  late Timer _updateTimer;
  Map<String, dynamic> _currentSensorData = {};

  @override
  void initState() {
    super.initState();

    // อัพเดทข้อมูลเซ็นเซอร์ทุกๆ 100 มิลลิวินาที
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateSensorData();
    });
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  void _updateSensorData() {
    final sensorData = _detectionManager.getCurrentSensorData();

    // เพิ่มข้อมูลลงในรายการสำหรับกราฟ
    final now = DateTime.now();
    final timeInSeconds = now.second + (now.millisecond / 1000);

    setState(() {
      _currentSensorData = sensorData;

      // เพิ่มข้อมูล accelerometer
      _accelerationReadings.add(SensorReading(
        time: timeInSeconds,
        value: sensorData['acceleration'] ?? 0.0,
      ));

      // เพิ่มข้อมูล barometer
      _heightReadings.add(SensorReading(
        time: timeInSeconds,
        value: sensorData['barometer_height'] ?? 0.0,
      ));

      // จำกัดจำนวนข้อมูลที่แสดง
      if (_accelerationReadings.length > 100) {
        _accelerationReadings.removeAt(0);
      }

      if (_heightReadings.length > 100) {
        _heightReadings.removeAt(0);
      }
    });
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

  // List<charts.Series<SensorReading, num>> _createAccelerationChartData() {
  //   return [
  //     charts.Series<SensorReading, num>(
  //       id: 'Acceleration',
  //       colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
  //       domainFn: (SensorReading reading, _) => reading.time,
  //       measureFn: (SensorReading reading, _) => reading.value,
  //       data: _accelerationReadings,
  //     )
  //   ];
  // }

  // List<charts.Series<SensorReading, num>> _createHeightChartData() {
  //   return [
  //     charts.Series<SensorReading, num>(
  //       id: 'Height',
  //       colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
  //       domainFn: (SensorReading reading, _) => reading.time,
  //       measureFn: (SensorReading reading, _) => reading.value,
  //       data: _heightReadings,
  //     )
  //   ];
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบและดีบัก'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                    value:
                        _currentSensorData['crash_speed']?.toStringAsFixed(1) ??
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

            // กราฟแสดงข้อมูล Acceleration
            // const Text(
            //   'กราฟความเร่ง (Acceleration)',
            //   style: TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),

            // const SizedBox(height: 8),

            // Container(
            //   height: 200,
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.blue.shade200),
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: charts.LineChart(
            //     _createAccelerationChartData(),
            //     animate: false,
            //     domainAxis: const charts.NumericAxisSpec(
            //       tickProviderSpec: charts.BasicNumericTickProviderSpec(
            //         desiredTickCount: 5,
            //       ),
            //     ),
            //     primaryMeasureAxis: const charts.NumericAxisSpec(
            //       tickProviderSpec: charts.BasicNumericTickProviderSpec(
            //         desiredTickCount: 5,
            //       ),
            //     ),
            //   ),
            // ),

            // const SizedBox(height: 24),

            // // กราฟแสดงข้อมูล Height
            // const Text(
            //   'กราฟความสูง (Height)',
            //   style: TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),

            // const SizedBox(height: 8),

            // Container(
            //   height: 200,
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.purple.shade200),
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: charts.LineChart(
            //     _createHeightChartData(),
            //     animate: false,
            //     domainAxis: const charts.NumericAxisSpec(
            //       tickProviderSpec: charts.BasicNumericTickProviderSpec(
            //         desiredTickCount: 5,
            //       ),
            //     ),
            //     primaryMeasureAxis: const charts.NumericAxisSpec(
            //       tickProviderSpec: charts.BasicNumericTickProviderSpec(
            //         desiredTickCount: 5,
            //       ),
            //     ),
            //   ),
            // ),

            const SizedBox(height: 32),

            // ปุ่มทดสอบการแจ้งเตือน
            const Text(
              'ทดสอบการแจ้งเตือน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 32),

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
                    SizedBox(height: 4),
                    Text(
                      '3. สังเกตค่าความเร่งและความสูงในกราฟเพื่อปรับค่าความไวให้เหมาะสม',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

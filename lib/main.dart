import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/monitoring_screen.dart';
import '../services/detection/detection_manager.dart';
import '../models/app_settings.dart';

void main() async {
  // ต้องเรียกก่อนใช้ native APIs
  WidgetsFlutterBinding.ensureInitialized();

  // ตั้งค่าการแสดงผลในแนวตั้งเท่านั้น
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // โหลดการตั้งค่าแอพ
  final settings = await AppSettings.loadFromPrefs();

  // ขอสิทธิ์ที่จำเป็นเมื่อเริ่มแอพ
  await _requestInitialPermissions();

  // เริ่มบริการตรวจจับตามการตั้งค่า
  final detectionManager = DetectionManager();

  // ตรวจสอบว่าควรเริ่มการตรวจจับทันทีหรือไม่
  if (settings.autoStartOnBoot ||
      settings.fallDetectionEnabled ||
      settings.crashDetectionEnabled) {
    await detectionManager.startDetection();
  }

  runApp(MyApp(settings: settings));
}

Future<void> _requestInitialPermissions() async {
  // ขอสิทธิ์ที่จำเป็นตั้งแต่เริ่มต้น
  await [
    Permission.sensors,
    Permission.activityRecognition,
    Permission.notification,
  ].request();

  // สิทธิ์ location อาจขอเมื่อผู้ใช้เปิดใช้งานการตรวจจับการชน
}

class MyApp extends StatelessWidget {
  final AppSettings settings;

  const MyApp({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบตรวจจับการล้มและการชน',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system, // ใช้ธีมตามการตั้งค่าระบบ
      home: const AppLifecycleObserver(
        child: MonitoringScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;

  const AppLifecycleObserver({
    super.key,
    required this.child,
  });

  @override
  _AppLifecycleObserverState createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  final DetectionManager _detectionManager = DetectionManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();
    final runInBackground = prefs.getBool('run_in_background') ?? true;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // แอพถูกซ่อนหรือไม่ได้ใช้งาน
      if (!runInBackground) {
        // ถ้าไม่ได้ตั้งค่าให้ทำงานเบื้องหลัง ให้หยุดการตรวจจับ
        _detectionManager.stopDetection();
      }
    } else if (state == AppLifecycleState.resumed) {
      // แอพกลับมาทำงานในหน้าจออีกครั้ง
      final fallDetectionEnabled =
          prefs.getBool('fall_detection_enabled') ?? false;
      final crashDetectionEnabled =
          prefs.getBool('crash_detection_enabled') ?? false;

      if ((fallDetectionEnabled || crashDetectionEnabled) &&
          !_detectionManager.isAnyDetectionActive) {
        // เริ่มการตรวจจับใหม่ถ้ามีการตั้งค่าให้เปิดใช้งาน
        await _detectionManager.startDetection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

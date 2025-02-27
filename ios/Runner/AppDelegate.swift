import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backgroundChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ลงทะเบียน BGTaskScheduler
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.appAccelerometer.refresh", using: nil) { task in
        self.handleBackgroundFetch(task: task as! BGAppRefreshTask)
      }
      
      BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.appAccelerometer.processing", using: nil) { task in
        self.handleBackgroundProcessing(task: task as! BGProcessingTask)
      }
    }
    
    // ตั้งค่า Flutter Method Channel
    let controller = window?.rootViewController as! FlutterViewController
    backgroundChannel = FlutterMethodChannel(name: "com.example.appAccelerometer/channel", binaryMessenger: controller.binaryMessenger)
    
    backgroundChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      switch call.method {
      case "registerAutoStart":
        self.scheduleBackgroundTasks()
        result(true)
      case "unregisterAutoStart":
        if #available(iOS 13.0, *) {
          BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.example.appAccelerometer.refresh")
          BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.example.appAccelerometer.processing")
        }
        result(true)
      case "configureBackgroundFetch":
        self.scheduleBackgroundFetch()
        result(true)
      case "configureBackgroundProcessing":
        self.scheduleBackgroundProcessing()
        result(true)
      case "setBackgroundFetchInterval":
        if let args = call.arguments as? [String: Any], let _ = args["seconds"] as? Int {
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "isRegisteredForAutoStart":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    
   private func testNotifications() {
        backgroundChannel?.invokeMethod("testNotification", arguments: nil) { result in
            if let success = result as? Bool, success {
                print("iOS: การทดสอบส่งการแจ้งเตือนสำเร็จ")
            } else {
                print("iOS: การทดสอบส่งการแจ้งเตือนล้มเหลว")
            }
        }
    }
  
  private func scheduleBackgroundTasks() {
    scheduleBackgroundFetch()
    scheduleBackgroundProcessing()
  }
  
  private func scheduleBackgroundFetch() {
    if #available(iOS 13.0, *) {
      let request = BGAppRefreshTaskRequest(identifier: "com.example.appAccelerometer.refresh")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 นาที
      
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        print("Could not schedule app refresh: \(error)")
      }
    } else {
      // การจัดการสำหรับ iOS เวอร์ชั่นเก่า
      UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
  }
  
  private func scheduleBackgroundProcessing() {
    if #available(iOS 13.0, *) {
      let request = BGProcessingTaskRequest(identifier: "com.example.appAccelerometer.processing")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 นาที
      request.requiresNetworkConnectivity = false
      request.requiresExternalPower = false
      
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        print("Could not schedule processing task: \(error)")
      }
    }
  }
  
  @available(iOS 13.0, *)
  private func handleBackgroundFetch(task: BGAppRefreshTask) {
    self.testNotifications()
    // สำรองงานไว้ก่อนหมดเวลา
    scheduleBackgroundFetch()
    
    // สร้าง task expiration handler
    let expirationHandler = {
      task.setTaskCompleted(success: false)
    }
    task.expirationHandler = expirationHandler
    
    // เรียกใช้งาน Flutter Background Channel
    backgroundChannel?.invokeMethod("onBackgroundFetch", arguments: nil) { result in
      if let success = result as? Bool {
        task.setTaskCompleted(success: success)
      } else {
        task.setTaskCompleted(success: false)
      }
      
      // ลงเวลาไว้อีกรอบ
      self.scheduleBackgroundFetch()
    }
  }
  
  @available(iOS 13.0, *)
  private func handleBackgroundProcessing(task: BGProcessingTask) {
    // สำรองงานไว้ก่อนหมดเวลา
    scheduleBackgroundProcessing()
    
    // สร้าง task expiration handler
    let expirationHandler = {
      task.setTaskCompleted(success: false)
    }
    task.expirationHandler = expirationHandler
    
    // เรียกใช้งาน Flutter Background Channel
    backgroundChannel?.invokeMethod("onBackgroundProcessing", arguments: nil) { result in
      if let success = result as? Bool {
        task.setTaskCompleted(success: success)
      } else {
        task.setTaskCompleted(success: false)
      }
      
      // ลงเวลาไว้อีกรอบ
      self.scheduleBackgroundProcessing()
    }
  }
  
  // สำหรับ iOS เวอร์ชันเก่ากว่า 13
  override func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    backgroundChannel?.invokeMethod("onBackgroundFetch", arguments: nil) { result in
      if let success = result as? Bool, success {
        completionHandler(.newData)
      } else {
        completionHandler(.noData)
      }
    }
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    // แจ้ง Flutter ว่าแอพกำลังจะปิด
    backgroundChannel?.invokeMethod("onAppWillTerminate", arguments: nil)
    super.applicationWillTerminate(application)
  }
}

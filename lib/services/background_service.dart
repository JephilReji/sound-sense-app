import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 1. Setup Notification Channel (Required for Android)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sound_sense_channel', // id
    'SoundSense Service', // title
    description: 'This channel is used for critical alerts.',
    importance: Importance.low, // Low importance = No sound/vibration for the status notification
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 2. Configure the Service
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // This is the function that runs in the background
      onStart: onStart,

      // CRITICAL FOR M2 TASKS:
      autoStart: false, // Set to false so we control it with the button first
      isForegroundMode: true, 
      
      // FIXED: Removed 'isSticky' (It is default now)
      
      notificationChannelId: 'sound_sense_channel',
      initialNotificationTitle: 'SoundSense Active',
      initialNotificationContent: 'Listening for danger...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

// 3. The "Undying" Function (Must be outside any class)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // The Heartbeat: Prints to console every 1 second
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "SoundSense Active",
          content: "Monitoring Environment... ${DateTime.now().second}",
        );
      }
    }

    // DEBUG LOG
    print('FLUTTER BACKGROUND SERVICE: Heartbeat ${DateTime.now()}');

    // Send data to UI
    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "status": "Active",
      },
    );
  });
}
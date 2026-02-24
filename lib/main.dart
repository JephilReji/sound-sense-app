import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundSense',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color.fromARGB(211, 13, 0, 54),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isRunning = false;
  DateTime? startTime;
  Timer? uiTimer;
  String runtimeText = "00:00:00";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _syncServiceState();
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.microphone,
      Permission.notification,
    ].request();

    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _syncServiceState() async {
    final service = FlutterBackgroundService();
    bool running = await service.isRunning();
    setState(() {
      isRunning = running;
      if (isRunning) {
        startTime = DateTime.now();
        _startUITimer();
      }
    });
  }

  void _startUITimer() {
    uiTimer?.cancel();
    uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime!);
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
        setState(() {
          runtimeText = "$hours:$minutes:$seconds";
        });
      }
    });
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    bool currentlyRunning = await service.isRunning();

    if (currentlyRunning) {
      service.invoke("stopService");
      uiTimer?.cancel();
      setState(() {
        isRunning = false;
        startTime = null;
        runtimeText = "00:00:00";
      });
    } else {
      await service.startService();
      setState(() {
        isRunning = true;
        startTime = DateTime.now();
      });
      _startUITimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SoundSense")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _toggleService,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? Colors.red : Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color: isRunning ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isRunning ? "STOP" : "START",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isRunning ? "Service Active" : "Service Inactive",
              style: TextStyle(
                color: isRunning ? Colors.green : Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (isRunning)
              Text(
                "Runtime: $runtimeText",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
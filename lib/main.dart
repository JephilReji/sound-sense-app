import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'services/background_service.dart'; // This import now works because we created File 2

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize the Background Service
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
        // High Contrast Theme for Accessibility
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212), // Dark Mode
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
  @override
  void initState() {
    super.initState();
    _checkPermissions(); // Ask for mic permission on startup
  }

  // 2. The Permission Logic
  Future<void> _checkPermissions() async {
    await [
      Permission.microphone,
      Permission.notification,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SoundSense Prototype")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hearing, size: 80, color: Colors.yellow),
            const SizedBox(height: 20),
            const Text(
              "Background Service Status:",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            // 3. Listen to the Service Status
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    "Service Inactive",
                    style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
                  );
                }
                final data = snapshot.data!;
                String time = data["current_date"]?.split("T").last.split(".").first ?? "Unknown";
                return Text(
                  "Active\nLast Ping: $time",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green, fontSize: 16),
                );
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                FlutterBackgroundService().invoke("stopService");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("STOP SERVICE (Debug)", style: TextStyle(color: Colors.white)),
            ),
             const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                 FlutterBackgroundService().startService();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("START SERVICE", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
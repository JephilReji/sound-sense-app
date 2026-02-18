import 'dart:async';
import 'dart:ui';
import 'dart:typed_data'; // Required for audio data processing
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart'; // The "Ears"
import 'package:tflite_flutter/tflite_flutter.dart'; // The "Brain"

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 1. Setup Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sound_sense_channel',
    'SoundSense Service',
    description: 'This channel is used for critical alerts.',
    importance: Importance.low,
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
      onStart: onStart,
      autoStart: false, 
      isForegroundMode: true, 
      notificationChannelId: 'sound_sense_channel',
      initialNotificationTitle: 'SoundSense Active',
      initialNotificationContent: 'Initializing AI Engine...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

// --- HELPER: Load the AI Model ---
Future<Interpreter> loadModel() async {
  try {
    // Ensure you have created assets/models/sound_classifier.tflite
    final interpreter = await Interpreter.fromAsset('assets/models/sound_classifier.tflite');
    print('M2 LOG: AI Model Loaded Successfully');
    return interpreter;
  } catch (e) {
    print('M2 ERROR: Failed to load model (Check assets folder) - $e');
    rethrow;
  }
}

// --- HELPER: Convert Raw Bytes to AI Input (Float32) ---
List<double> processAudioBytes(Uint8List data) {
  // 1. View raw bytes as 16-bit integers (PCM data)
  Int16List pcmData = Int16List.view(data.buffer);
  
  // 2. Create a float list to hold normalized values
  List<double> floatData = List<double>.filled(pcmData.length, 0.0);
  
  // 3. Normalize: Convert Int16 (-32768 to 32767) to Float32 (-1.0 to 1.0)
  for (int i = 0; i < pcmData.length; i++) {
    floatData[i] = pcmData[i] / 32768.0; 
  }
  return floatData;
}

// 3. The "Undying" Function
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // --- SERVICE SETUP ---
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

  // --- FEB 11 TASK: INTEGRATION ---
  
  // 1. Initialize Recorder
  final AudioRecorder audioRecorder = AudioRecorder();
  
  // 2. Initialize AI Interpreter
  Interpreter? interpreter;
  try {
    interpreter = await loadModel();
  } catch (e) {
    print("WARNING: Running service without AI Model.");
  }

  // 3. Start Listening (The Ears)
  try {
    if (await audioRecorder.hasPermission()) {
      print("M2 LOG: Microphone Permission Granted. Starting Stream...");

      // Configure for Standard AI Audio: 16kHz, Mono, 16-bit PCM
      final stream = await audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, 
          sampleRate: 16000, 
          numChannels: 1,
        ),
      );

      // 4. Process Incoming Audio (The Loop)
      stream.listen((data) {
        // A. Convert bytes to numbers the AI understands
        // Note: Real models need a fixed input size (e.g., 15600 samples).
        // For now, we process whatever chunks we get.
        List<double> input = processAudioBytes(data);
        
        // B. Calculate "Energy" (Volume) for UI visualization
        double energy = 0.0;
        if (input.isNotEmpty) {
           // Simple Root Mean Square (RMS) calculation
           double sum = input.fold(0, (prev, elem) => prev + (elem * elem));
           energy = sum / input.length;
        }

        // C. Run Inference (If model is loaded)
        if (interpreter != null) {
          // Placeholder for inference logic. 
          // Real logic depends on your model's specific input shape (e.g. [1, 16000])
          
          // var output = List.filled(3, 0.0).reshape([1, 3]);
          // interpreter.run(input, output);
        }

        // D. Send Update to UI
        service.invoke(
          'update',
          {
            "status": "Listening...",
            "energy": (energy * 1000).toStringAsFixed(2), // Amplify for visibility
            "model_status": interpreter != null ? "Active" : "Not Loaded",
          },
        );
      });
      
    } else {
      print("M2 ERROR: Microphone permission missing.");
    }
  } catch (e) {
    print("M2 CRITICAL ERROR: $e");
  }

  // --- HEARTBEAT (Reduced noise) ---
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "SoundSense Active",
          content: "AI Engine Running... ${DateTime.now().second}",
        );
      }
    }
  });
}
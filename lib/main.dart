import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:p2prunningapp/services/mqtt_service.dart';
import 'package:p2prunningapp/sensors/gps.dart';
import 'package:p2prunningapp/sensors/imu.dart';
import 'ui/login/login.dart';
import 'package:p2prunningapp/services/bleService.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // Load environment variables
  runApp(const MyApp());
}

final ThemeData appTheme = ThemeData(

  primaryColor: const Color(0xFF00FF77), // Neon green as the primary color
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: const Color(0xFF00FF77), // Neon green
    secondary: const Color(0xFF00BFFF), // Blue for accent
    surface: const Color(0xFF1A1A1A), // Dark gray for background
  ),
  scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Dark background for the app
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00FF77), // Neon green for AppBar
    elevation: 0, // Optional: remove shadow for a flat look
    iconTheme: IconThemeData(color: Colors.white), // White icons
    titleTextStyle: TextStyle(
      color: Colors.white, // White text for title
      fontSize: 20, // Customize the font size if needed
      fontWeight: FontWeight.bold,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    titleLarge: TextStyle(color: Color(0xFF00FF77)), // Use neon green for titles
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.1), // Slight transparency
    labelStyle: const TextStyle(color: Color(0xFF00FF77)), // Neon green labels
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00FF77), width: 2.0),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 1.0),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white, backgroundColor: const Color(0xFF00BFFF), // White text on buttons
    ),
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    onStart(context);
    return MaterialApp(
      title: 'Peer2Peer Running',
      theme: appTheme,
      home: const LoginScreen(), // Set LoginScreen as the initial screen
    );
  }}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Text('Welcome to Peer2Peer Running!'),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
          ),
        ),
      ),
    );
  }
}

void onStart(BuildContext context) async {
  final bleService = BLEService();
  await bleService.initialize(context);
  //await bleService.startScan();
  await bleService.connectToDevice();
  final mqttService = MQTTService();
  await mqttService.initializeMQTT();

  final gpsService = GPSService();
  final imuService = IMUService();

  final bool shouldSendData = true;
  Timer.periodic(const Duration(seconds: 30), (timer) {
    if (mqttService.client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT connection is alive.');

      if (shouldSendData) {

        imuService.sendIMUData(1.0, 0.0, 0.0);
      }
    } else {
      print('MQTT connection lost. Attempting to reconnect...');
      mqttService.initializeMQTT();
    }
  });
}
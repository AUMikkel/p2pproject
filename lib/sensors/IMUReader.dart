import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class IMUReader {
  static final IMUReader _instance = IMUReader._internal();

  factory IMUReader() {
    return _instance;
  }

  IMUReader._internal() {
    _initialize();
  }

  final StreamController<Map<String, dynamic>> _accelerometerController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _gyroscopeController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _magnetometerController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get accelerometerStream => _accelerometerController.stream;
  Stream<Map<String, dynamic>> get gyroscopeStream => _gyroscopeController.stream;
  Stream<Map<String, dynamic>> get magnetometerStream => _magnetometerController.stream;

  void _initialize() {
    accelerometerEventStream().listen((AccelerometerEvent event) {
      final int timestamp = DateTime.now().microsecondsSinceEpoch;
      _accelerometerController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
    });
    gyroscopeEventStream().listen((GyroscopeEvent event) {
      final int timestamp = DateTime.now().microsecondsSinceEpoch;
      _gyroscopeController.add({'timestamp': timestamp, 'data': (event.x, event.y, event.z)});
    });
    magnetometerEventStream().listen((MagnetometerEvent event) {
      final int timestamp = DateTime.now().microsecondsSinceEpoch;
      _magnetometerController.add({'timestamp': timestamp, 'data': (event.x, event.y, event.z)});
    });
  }

  void dispose() {
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
  }
}
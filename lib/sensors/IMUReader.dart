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

  final StreamController<List<double>> _accelerometerController = StreamController<List<double>>.broadcast();
  final StreamController<List<double>> _gyroscopeController = StreamController<List<double>>.broadcast();
  final StreamController<List<double>> _magnetometerController = StreamController<List<double>>.broadcast();

  Stream<List<double>> get accelerometerStream => _accelerometerController.stream;
  Stream<List<double>> get gyroscopeStream => _gyroscopeController.stream;
  Stream<List<double>> get magnetometerStream => _magnetometerController.stream;

  void _initialize() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      _accelerometerController.add([event.x, event.y, event.z]);
    });
    gyroscopeEvents.listen((GyroscopeEvent event) {
      _gyroscopeController.add([event.x, event.y, event.z]);
    });
    magnetometerEvents.listen((MagnetometerEvent event) {
      _magnetometerController.add([event.x, event.y, event.z]);
    });
  }

  void dispose() {
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
  }
}
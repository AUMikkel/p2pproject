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
  final Duration _sensorInterval = SensorInterval.normalInterval; // Default interval

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;


    /*userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final int timestamp = DateTime.now().microsecondsSinceEpoch;
      _accelerometerController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
    });*/
    void _initialize() {
      print('Sensor interval: $_sensorInterval');
      /*
      _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        final int timestamp = DateTime.now().microsecondsSinceEpoch;
        if (!_accelerometerController.isClosed) {
          _accelerometerController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
        }
      });
      */
      _userAccelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final int timestamp = DateTime.now().microsecondsSinceEpoch;
      _accelerometerController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
    });

      _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
        final int timestamp = DateTime.now().microsecondsSinceEpoch;
        if (!_gyroscopeController.isClosed) {
          _gyroscopeController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
        }
      });

      _magnetometerSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
        final int timestamp = DateTime.now().microsecondsSinceEpoch;
        if (!_magnetometerController.isClosed) {
          _magnetometerController.add({'timestamp': timestamp, 'data': [event.x, event.y, event.z]});
        }
      });
    }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _userAccelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
  }
}
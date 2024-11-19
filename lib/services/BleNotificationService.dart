import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:p2prunningapp/utils/bleUtils.dart';
import 'package:p2prunningapp/services/bleScan.dart';
import 'package:p2prunningapp/services/bleDevice.dart';
import 'package:p2prunningapp/services/bleService.dart';

class BleNotificationService {
  static final BleNotificationService _instance = BleNotificationService._internal();
  factory BleNotificationService() => _instance;
  BleNotificationService._internal();

  final List<String> _imuDataMessages = [];
  final List<String> _runControlMessages = [];
  StreamSubscription<List<int>>? _imuDataSubscription;
  StreamSubscription<List<int>>? _runControlSubscription;

  List<String> get imuDataMessages => _imuDataMessages;
  List<String> get runControlMessages => _runControlMessages;
  BluetoothDevice? _connectedDevice;

  final StreamController<String> _receivedMessagesController = StreamController<String>.broadcast();
  Stream<String> get receivedMessagesStream => _receivedMessagesController.stream;

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connectAndUpdateStream();
    _connectedDevice = device;
    startListeningToNotifications(device);
  }

  void startListeningToNotifications(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          if (characteristic.uuid.toString().toUpperCase() == "AE4B02CC-DF79-6EF4-51D8-36EB0E0B0F13") {
            // IMU data characteristic
            await characteristic.setNotifyValue(true);
            _imuDataSubscription = characteristic.value.listen((value) {
              int imuData = int.parse(String.fromCharCodes(value));
              String recievedTime = nanosecondsToTimestamp(imuData);
              String timestamp = DateTime.now().toString();
              String message = '[$timestamp] $recievedTime';
              _imuDataMessages.add(message);
              _receivedMessagesController.add(message);
            });
          } else if (characteristic.uuid.toString().toUpperCase() == "AE4B02CC-DF79-6EF4-51D8-36EB0E0B0F14") {
            // Start/stop run characteristic
            await characteristic.setNotifyValue(true);
            _runControlSubscription = characteristic.value.listen((value) {
              String runControlMessage = String.fromCharCodes(value);
              String timestamp = DateTime.now().toString();
              String message = '[$timestamp] $runControlMessage';
              _runControlMessages.add('[$timestamp] $runControlMessage');
              _receivedMessagesController.add(message);
            });
          }
        }
      }
    }
  }

  String nanosecondsToTimestamp(int nanoseconds) {
    int milliseconds = nanoseconds ~/ 1000000;
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return dateTime.toIso8601String();
  }

  String getIMULastMessages() {
    if (_imuDataMessages.isNotEmpty) {
      return _imuDataMessages.last;
    } else {
      return 'No messages received';
    }
  }

  List<String> getIMUMessages() {
    if (_imuDataMessages.isNotEmpty) {
      return _imuDataMessages;
    } else {
      return ['No messages received'];
    }
  }

  String getRunControlLatestMessage() {
    if (_runControlMessages.isNotEmpty) {
      return _runControlMessages.last;
    } else {
      return 'No messages received';
    }
  }

  void stopListeningToNotifications() {
    _imuDataSubscription?.cancel();
    _runControlSubscription?.cancel();
  }

  void disconnectFromDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
  }
}
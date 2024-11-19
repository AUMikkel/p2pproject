import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:p2prunningapp/utils/bleUtils.dart';
import 'package:p2prunningapp/services/bleScan.dart';
import 'package:p2prunningapp/services/bleDevice.dart';
import 'package:p2prunningapp/services/bleService.dart';
import 'package:permission_handler/permission_handler.dart';

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
            _imuDataSubscription = characteristic.value.listen((value) async {
              int receivedTime = int.parse(String.fromCharCodes(value));
              int timestamp = DateTime.now().millisecondsSinceEpoch;
              String message = 'Mobile Timestamp: [$timestamp], Ble Timestamp: $receivedTime';
              _imuDataMessages.add(message);
              _receivedMessagesController.add(message);
              await _logData(message);
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

  Future<void> saveLogFileToExternalStorage() async {
    try {
      // Request storage permissions
      if (await Permission.storage.request().isGranted) {
        final directory = await getExternalStorageDirectory();
        final file = File('${directory!.path}/ble_delay_exp.txt');
        final logFile = File('${(await getApplicationDocumentsDirectory()).path}/ble_delay_exp.txt');

        if (await logFile.exists()) {
          await file.writeAsBytes(await logFile.readAsBytes());
          print('Log file saved to external storage: ${file.path}');
        } else {
          print('Log file does not exist.');
        }
      } else {
        print('Storage permission not granted.');
      }
    } catch (e) {
      print('Error saving log file: $e');
    }
  }

  Future<void> _logData(String message) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/ble_delay_exp.txt');
    await file.writeAsString('$message\n', mode: FileMode.append);
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
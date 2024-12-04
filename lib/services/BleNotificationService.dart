import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:p2prunningapp/utils/bleUtils.dart';
import 'package:p2prunningapp/services/bleScan.dart';
import 'package:p2prunningapp/services/bleDevice.dart';
import 'package:p2prunningapp/services/bleService.dart';
import 'package:permission_handler/permission_handler.dart';

enum SyncState { WaitingForT1, WaitingForT4 }

class BleNotificationService {
  static final BleNotificationService _instance = BleNotificationService._internal();
  factory BleNotificationService() => _instance;
  BleNotificationService._internal();

  final List<String> _imuDataMessages = [];
  final List<String> _runControlMessages = [];


  StreamSubscription<List<int>>? _imuDataSubscription;
  late StreamSubscription<List<int>>? _runControlSubscription;

  List<String> get imuDataMessages => _imuDataMessages;
  List<String> get runControlMessages => _runControlMessages;
  BluetoothDevice? _connectedDevice;

  final StreamController<String> _receivedMessagesController = StreamController<String>.broadcast();
  Stream<String> get receivedMessagesStream => _receivedMessagesController.stream;

  final StreamController<Map<String, dynamic>> _imuDataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get imuDataStream => _imuDataController.stream;


  final List<int> _clockSyncList = [];
  SyncState _syncState = SyncState.WaitingForT1;
  bool _isProcessing = false; // Prevent overlapping sync cycles

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connectAndUpdateStream();
    _connectedDevice = device;
    startListeningToNotifications(device);
  }
  Future<void> startListeningToNotifications(BluetoothDevice device) async {
    final List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify &&
            characteristic.uuid.toString().toUpperCase() == "AE4B02CC-DF79-6EF4-51D8-36EB0E0B0F13") {
          await characteristic.setNotifyValue(true);

          _runControlSubscription = characteristic.value.listen((value) async {
            final String message = String.fromCharCodes(value);
            _receivedMessagesController.add(message); // Add message to the stream
          });
        }
      }
    }
  }

  Future<void> startListeningToIMUData() async {
    if (_connectedDevice == null) {
      print('No connected device.');
      return;
    }

    final List<BluetoothService> services = await _connectedDevice!.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify &&
            characteristic.uuid.toString().toUpperCase() == "AE4B02CC-DF79-6EF4-51D8-36EB0E0B0F14") {
          await characteristic.setNotifyValue(true);

          _imuDataSubscription = characteristic.value.listen((value) async {
            // Timestamp the IMU data and add it to the stream
            final String message = String.fromCharCodes(value);
            final int timestamp = DateTime.now().microsecondsSinceEpoch;
            _imuDataController.add({'timestamp': timestamp, 'data': message}); // Add IMU data to the stream
          });
        }
      }
    }
  }

  /*
  Future<void> startListeningToNotifications(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify &&
            characteristic.uuid.toString().toUpperCase() == "AE4B02CC-DF79-6EF4-51D8-36EB0E0B0F14") {
          await characteristic.setNotifyValue(true);

          _runControlSubscription = characteristic.value.listen((value) async {
            if (_isProcessing) return; // Avoid overlapping sync processes
            _isProcessing = true;

            try {
              final String message = String.fromCharCodes(value);
              switch (_syncState) {
                case SyncState.WaitingForT1:
                  await _handleFirstPhase(characteristic, message);
                  break;
                case SyncState.WaitingForT4:
                  await _handleSecondPhase(message);
                  break;
              }
            } catch (e) {
              print('Error during synchronization: $e');
            } finally {
              _isProcessing = false;
            }
          });
        }
      }
    }
  }
*/
  Future<void> _handleFirstPhase(BluetoothCharacteristic characteristic, String message) async {
    try {
      // Parse T1 from the BLE message
      final int T1 = int.parse(message);
      final int T2 = DateTime.now().microsecondsSinceEpoch;

      print('T1: $T1');
      print('T2: $T2');

      // Take T3 just before sending the value
      final int T3 = DateTime.now().microsecondsSinceEpoch;
      try {
        await characteristic.write(T3.toString().codeUnits);
        print('T3: $T3');
        print('Successfully sent T3 to BLE device');

        // Save T1, T2, T3 for later use
        _clockSyncList.clear();
        _clockSyncList.addAll([T1, T2, T3]);

        // Proceed to the next state
        _syncState = SyncState.WaitingForT4;
      } catch (e) {
        print('Failed to send T3: $e');
        _resetSynchronization(); // Reset the synchronization process
      }
    } catch (e) {
      print('Error in synchronization: $e');
      _resetSynchronization(); // Reset state on unexpected error
    }
  }

  void _resetSynchronization() {
    _syncState = SyncState.WaitingForT1; // Reset state machine
    _clockSyncList.clear(); // Clear any partial data
    print('Synchronization process reset.');
  }

  Future<void> _handleSecondPhase(String message) async {
    // Parse T4 from the BLE message
    final int T4 = int.parse(message);
    print('T4: $T4');

    // Retrieve T1, T2, T3 from the list
    final int T1 = _clockSyncList[0];
    final int T2 = _clockSyncList[1];
    final int T3 = _clockSyncList[2];

    // Calculate offset (Δ) and delay (d)
    final double delta = ((T2*1000 - T1) - (T4-1000000 - T3*1000)) / 2.0;
    final double delay = ((T2*1000 - T1) + (T4-1000000 - T3*1000)) / 2.0;

    print('Clock Offset (Δ): $delta µs');
    print('Propagation Delay (d): $delay µs');

    // Log the synchronization data
    final String logEntry = '$T1, $T2, $T3, $T4, Δ: $delta, d: $delay';
    await _logData(logEntry, 'ble_delay_offset_exp8');

    // Reset state for the next synchronization cycle
    _syncState = SyncState.WaitingForT1;
    _clockSyncList.clear();
  }

  Future<void> saveLogFileToExternalStorage(String fileName) async {
    try {
      // Request storage permissions
      if (await Permission.storage.request().isGranted) {
        final directory = await getExternalStorageDirectory();
        final file = File('${directory!.path}/${fileName}.txt');
        final logFile = File('${(await getApplicationDocumentsDirectory()).path}/${fileName}.txt');

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

  Future<void> _logData(String message, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${fileName}.txt');
    await file.writeAsString('$message\n', mode: FileMode.append);
  }

  void stopListeningToIMUData() {
    _imuDataSubscription?.cancel();
  }

  void stopListeningToNotifications() {
    _runControlSubscription?.cancel();
  }

  void disconnectFromDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
  }

  void dispose() {
    _receivedMessagesController.close();
    _imuDataController.close();
  }

}
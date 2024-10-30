import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

class BLEService {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus();
  List<ScanResult> _scanResults = [];

  Future<void> initialize(BuildContext context) async {
    if (await FlutterBluePlus.isSupported == false) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Bluetooth Not Supported'),
            content: Text('Bluetooth is not supported by this device.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    var subscription = FlutterBluePlus.adapterState.listen((
        BluetoothAdapterState state) {
      print(state);
      if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc

      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Bluetooth is not enabled'),
              content: Text('Enable Bluetooth to use this app.'),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }


  Future<void> startScan() async {
    // Clear previous scan results
    _scanResults.clear();
    // listen to scan results
    // Note: `onScanResults` clears the results between scans. You should use
    //  `scanResults` if you want the current scan results *or* the results from a previous scan.
    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      _scanResults = results;
      for (ScanResult r in results) {
        print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
      }
    },
      onError: (e) => print(e),
    );

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    // Start scanning w/ timeout
    // Optional: use `stopScan()` as an alternative to timeout
    print("-----------------------------------------");
    await FlutterBluePlus.startScan(
        //withServices: [Guid("180D")], // match any of the specified services
        //withNames: ["ble-uart"], // *or* any of the specified names
        timeout: Duration(seconds: 15));

    // wait for scanning to stop
    await FlutterBluePlus.isScanning
        .where((val) => val == false)
        .first;

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);
    print("-----------------------------------------");
    // get the scan results
    var __scanResults = getScanResults();
    print('Scan results: ${__scanResults.length} devices found.');
    print('Scan results: ${__scanResults}');
  }

  List<ScanResult> getScanResults() {
    return _scanResults;
  }

  Future<void> connectToDevice(String deviceId) async {
    try {
      // Find the device from the scan results
      //ScanResult? targetResults = _scanResults.firstWhere((result) => result.device.remoteId.str == deviceId, orElse: () => null);
      var targetResult = null;
      // loop through _scanResults list to find the device
      for (ScanResult result in _scanResults) {
        if (result.device.remoteId.str == deviceId) {
          targetResult = result;
          break;
        }
      }

      if (targetResult != null) {
        BluetoothDevice device = targetResult.device;

        // Listen for disconnection
        var subscription = device.connectionState.listen((BluetoothConnectionState state) async {
          if (state == BluetoothConnectionState.disconnected) {
            // 1. typically, start a periodic timer that tries to
            //    reconnect, or just call connect() again right now
            // 2. you must always re-discover services after disconnection!
            // Connect to the device
            print('${device.disconnectReason?.code} ${device.disconnectReason?.description}');
            await device.connect();
            print('Connected to device: $deviceId');
          }
        });
        // Cleanup: cancel subscription when disconnected
        //   - [delayed] This option is only meant for `connectionState` subscriptions.
        //     When `true`, we cancel after a small delay. This ensures the `connectionState`
        //     listener receives the `disconnected` event.
        //   - [next] if true, the stream will be canceled only on the *next* disconnection,
        //     not the current disconnection. This is useful if you setup your subscriptions
        //     before you connect.
        device.cancelWhenDisconnected(subscription, delayed: true, next: true);

        await device.connect();
        print('Connected to device: $deviceId');

        // Cancel to prevent duplicate listeners
        subscription.cancel();
      } else {
        print('Device not found.');
      }
    } catch (e) {
      print('Failed to connect: $e');
    }
  }

  Future<void> disconnect(String deviceId) async {
    try {
      // Get a list of currently connected devices and find the one you want to disconnect
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      //BluetoothDevice targetDevice = connectedDevices.firstWhere((d) => d.remoteId.str == deviceId,orElse: () => dummyDevice);

      var targetDevice = null;
      // loop through _scanResults list to find the device
      for (BluetoothDevice result in connectedDevices) {
        if (result.remoteId.str == deviceId) {
          targetDevice = result;
          break;
        }
      }

      if (targetDevice.remoteId.str != null) {
        await targetDevice.disconnect();
        print('Disconnected from device: $deviceId');
      } else {
        print('Device not connected.');
      }
    } catch (e) {
      print('Failed to disconnect: $e');
    }
  }
  void stopScan() {
    //pass
  }

  Future<void> saveDevice(String deviceId) async {
    final String remoteId = await File('/remoteId.txt').readAsString();
    var device = BluetoothDevice.fromId(remoteId);
    // AutoConnect is convenient because it does not "time out"
    // even if the device is not available / turned off.
    await device.connect(autoConnect: true);
  }

  Future<void> sendDataToDevice(BluetoothDevice device, List<int> data) async {
    try {
      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find the service and characteristic you want to write to
      BluetoothService targetService;
      BluetoothCharacteristic? targetCharacteristic;

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            targetService = service;
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic != null) {
        // Write data to the characteristic
        await targetCharacteristic.write(data);
        print('Data sent to device: ${device.remoteId}');
      } else {
        print('No writable characteristic found.');
      }
    } catch (e) {
      print('Failed to send data: $e');
    }
  }
}

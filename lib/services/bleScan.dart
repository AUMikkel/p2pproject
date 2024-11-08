import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/bleUtils.dart';

class BLEScan {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  void initialize() {
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
    }, onError: (e) {
      print('Scan Error: $e');
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
    });
  }

  // dispose job is to cancel the subscription
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
  }

  // startScan job is to start scanning for devices
  Future startScan() async{
    try  {
      // `withServices` is required on iOS for privacy purposes, ignored on android.
      var withServices = [Guid("180f")]; // Battery Level Service
      _systemDevices = await FlutterBluePlus.systemDevices(withServices);
    } catch (e) {
      print('System Devices Error: $e');
    }
    try {
      var withName = ['M5UiFlow'];
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print('Start Scan Error: $e');
    }
  }

  Future stopScan() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop Scan Error: $e');
    }
  }

  // Connect to a device
  void connectToDevice(BluetoothDevice device) {
    device.connectAndUpdateStream().catchError((e) {
      print('Connect Error: $e');
    });
  }

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
}


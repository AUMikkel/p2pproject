import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:p2prunningapp/utils/bleUtils.dart';

class BLEDevice {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  void initialize(BluetoothDevice device) {
    _connectionStateSubscription = device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await device.readRssi();
      }
    });

    _mtuSubscription = device.mtu.listen((value) {
      _mtuSize = value;
    });

    _isConnectingSubscription = device.isConnecting.listen((value) {
      _isConnecting = value;
    });

    _isDisconnectingSubscription = device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
    });
  }

  // Cancel the subscription
  void dispose() {
    _connectionStateSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _mtuSubscription.cancel();
  }

  Future connectToDevice(BluetoothDevice device) async {
    try {
      await device.connectAndUpdateStream();
    } catch (e) {
      print('Connect Error: $e');
    }
  }

  Future onDisconnect(BluetoothDevice device) async {
    try {
      await device.disconnectAndUpdateStream();
    } catch (e) {
      print('Disconnect Error: $e');
    }
  }

  Future onDiscoverServices(BluetoothDevice device) async {
    try {
      _services = await device.discoverServices();
    } catch (e) {
      print('Discover Services Error: $e');
    }
  }

  Future onRequestMtu(BluetoothDevice device) async {
    try {
      await device.requestMtu(223, predelay: 0);
      print('Request Mtu: Success');
    } catch (e) {
      print('Request MTU Error: $e');
    }
  }

  // List of services
  List<BluetoothService> listBluetoothServices(BluetoothDevice device) {
    return _services.map((service) {
      return service;
    }).toList();
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:p2prunningapp/services/bleScan.dart';
import 'package:p2prunningapp/services/bleDevice.dart';
import 'package:p2prunningapp/services/bleService.dart';
import 'package:p2prunningapp/utils/bleUtils.dart';

class RecordRunsScreen extends StatefulWidget {
  const RecordRunsScreen({Key? key}) : super(key: key);
  @override
  State<RecordRunsScreen> createState() => _RecordRunsScreenState();
}

class _RecordRunsScreenState extends State<RecordRunsScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  List<String> _receivedMessages = [];
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<List<int>> _notificationSubscription;
  //final BLEScan _bleScan = BLEScan();
  //final BLEDevice _bleDevice = BLEDevice();
  //final BLEService _bleService = BLEService();

  @override
  void initState() {
    super.initState();
    //_bleScan.initialize();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      // Snack bar displaying scan errer and the errer e
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    //_bleScan.dispose();
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _notificationSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      // `withServices` is required on iOS for privacy purposes, ignored on android.
      var withServices = [Guid("180f")]; // Battery Level Service
      _systemDevices = await FlutterBluePlus.systemDevices(withServices);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('System Devices Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    try {
      var withName = ['M5UiFlow'];
      await FlutterBluePlus.startScan(withNames: withName, timeout: const Duration(seconds: 15));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Start Scan Error:: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stop Scan Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /*
  void onConnectPressed(BluetoothDevice device) {
    device.connectAndUpdateStream().catchError((e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    });
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) => DeviceScreen(device: device), settings: RouteSettings(name: '/DeviceScreen'));
    Navigator.of(context).push(route);
  }*/
  void _startListeningToNotifications(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          _notificationSubscription = characteristic.value.listen((value) {
            String message = String.fromCharCodes(value);
            setState(() {
              _receivedMessages.add(message);
            });
          });
          break;
        }
      }
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    device.connectAndUpdateStream().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}'),
          backgroundColor: Colors.green,
        ),
      );
      _startListeningToNotifications(device);
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Future onRefresh() {
    if (_isScanning == false) {
      var withName = ['M5UiFlow'];
      FlutterBluePlus.startScan(withNames: withName, timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

Widget buildReceivedMessages(BuildContext context) {
  return Column(
    children: _receivedMessages.map((message) => ListTile(
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
      ),
      isThreeLine: true,
    )).toList(),
  );
}

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
      );
    } else {
      return FloatingActionButton(child: const Text("SCAN"), onPressed: onScanPressed);
    }
  }

  List<Widget> _buildSystemDeviceTiles(BuildContext context) {
    return _systemDevices
        .map(
          (d) => SystemDeviceTile(
        device: d,
        onConnect: () => onConnectPressed(d),
      ),
    )
        .toList();
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .map(
          (r) => ScanResultTile(
        result: r,
        onTap: () => onConnectPressed(r.device),
      ),
    )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      //key: SnackBar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
        ),
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            children: <Widget>[
              ..._buildSystemDeviceTiles(context),
              ..._buildScanResultTiles(context),
              buildReceivedMessages(context),
            ],
          ),
        ),
        floatingActionButton: buildScanButton(context),
      ),
    );
  }
/*
  void _startScan() async {
    await _bleScan.startScan();
    await Future.delayed(Duration(seconds: 15));
    print(_bleScan.scanResults);
    setState(() {});
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await _bleDevice.connectToDevice(device);
      Navigator.of(context).pop(); // Close the popup after connecting
    } catch (e) {
      print('Connection Error: $e');
    }
  }
*/
/*  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Not Connected to Bluetooth Watch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please scan for devices and connect to your Bluetooth watch.'),
          SizedBox(height: 20),
          _bleScan.isScanning
              ? CircularProgressIndicator()
              : ElevatedButton(
            onPressed: _startScan,
            child: Text('Scan for Devices'),
          ),
          SizedBox(height: 20),
          _bleScan.scanResults.isEmpty
              ? const Text('No devices found.')
              : Column(
            children: _bleScan.scanResults.map((result) {
              return ListTile(
                title: Text(result.device.name),
                subtitle: Text(result.device.id.toString()),
                onTap: () => _connectToDevice(result.device),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
 */
}

class SystemDeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onConnect;

  const SystemDeviceTile({
    Key? key,
    required this.device,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(device.name),
      subtitle: Text(device.id.toString()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device Info: ${device.name} (${device.id})'),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

class ScanResultTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const ScanResultTile({
    Key? key,
    required this.result,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(result.device.name.isNotEmpty ? result.device.name : 'Unknown Device',
      style: TextStyle(
        color: result.device.name.isNotEmpty ? Colors.white : Colors.grey),
      ),
      subtitle: Text(result.device.id.toString(),
      style: TextStyle(
        color: result.device.name.isNotEmpty ? Colors.white : Colors.grey),
      ),
      trailing: IconButton(
        icon: Icon(Icons.bluetooth, color: Colors.lightBlue),
        onPressed: onTap,
      ),
    );
  }
}
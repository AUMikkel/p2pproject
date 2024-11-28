import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/BleNotificationService.dart';

class BleScanConnectionScreen extends StatefulWidget {
  const BleScanConnectionScreen({Key? key}) : super(key: key);
  @override
  State<BleScanConnectionScreen> createState() => _BleScanConnectionScreenState();
}

class _BleScanConnectionScreenState extends State<BleScanConnectionScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  List<String> _receivedMessages = [];
  String _receivedMessagesLast = "Nothing recieved";

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
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
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
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
          content: Text('Start Scan Error: $e'),
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

  void onConnectPressed(BluetoothDevice device) {
    BleNotificationService().connectToDevice(device).then((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Connected'),
            content: Text('Connected to ${device.name}'),
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
      device.requestMtu(50, predelay: 0).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MTU size requested successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request MTU Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      });
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
    return StreamBuilder<String>(
      stream: BleNotificationService().receivedMessagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _receivedMessages.add(snapshot.data!);
          _receivedMessagesLast = snapshot.data!;
          print('Received message: $_receivedMessagesLast');
        }
        return Column(
          children: _receivedMessages.map((message) => ListTile(
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
            isThreeLine: false,
          )).toList(),
        );
      },
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
              ElevatedButton(
                onPressed: () async {
                  await BleNotificationService().saveLogFileToExternalStorage('ble_delay_offset_exp6');
                },
                child: Text('Save Log File'),
              ),
            ],
          ),
        ),
        floatingActionButton: buildScanButton(context),
      ),
    );
  }
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
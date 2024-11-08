import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  Future<void> sendDataToDevice(BluetoothDevice device, List<int> data) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic != null) {
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
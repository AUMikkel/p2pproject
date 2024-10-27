import 'package:p2prunningapp/services/mqtt_service.dart';

class GPSService {
  void sendGPSData(double latitude, double longitude) {
    final gpsData = '{"latitude": $latitude, "longitude": $longitude}';
    MQTTService().publishMessage('sensor/gps', gpsData);
    print('GPS data sent: $gpsData');
  }
}
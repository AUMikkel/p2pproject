import 'package:p2prunningapp/services/mqtt_service.dart';

class IMUService {
  void sendIMUData(double roll, double pitch, double yaw) {
    final imuData = '{"roll": $roll, "pitch": $pitch, "yaw": $yaw}';
    MQTTService().publishMessage('sensor/imu', imuData);
    print('IMU data sent: $imuData');
  }
}
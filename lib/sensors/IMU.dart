import 'dart:async';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:p2prunningapp/services/mqtt_service.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';

class IMUService {
  final
BuildContext context;  StreamSubscription<Activity>? _activitySubscription;

  IMUService(this.context) {
    _initializeActivityRecognition();
  }

  // Function to initialize activity recognition
  void _initializeActivityRecognition() async {
    if (await _checkAndRequestPermission()) {
      _subscribeActivityStream();
    }
  }

  // Request necessary permissions
  Future<bool> _checkAndRequestPermission() async {
    ActivityPermission permission = await FlutterActivityRecognition.instance.checkPermission();
    if (permission == ActivityPermission.PERMANENTLY_DENIED) {
      return false;
    } else if (permission == ActivityPermission.DENIED) {
      permission = await FlutterActivityRecognition.instance.requestPermission();
      if (permission != ActivityPermission.GRANTED) {
        return false;
      }
    }
    return true;
  }

  // Callback for detected activities
  void _onActivity(Activity activity) {
    print('Activity detected >> ${activity.toJson()}');
    _showActivityPopup(activity);
  }

  // Callback for errors in activity recognition
  void _onError(dynamic error) {
    print('Error in activity recognition >> $error');
  }

  // Subscribe to activity stream
  void _subscribeActivityStream() {
    _activitySubscription = FlutterActivityRecognition.instance.activityStream
        .handleError(_onError)
        .listen(_onActivity);
  }

  // Method to send IMU data
  void sendIMUData(double roll, double pitch, double yaw) {
    final imuData = '{"roll": $roll, "pitch": $pitch, "yaw": $yaw}';
    MQTTService().publishMessage('sensor/imu', imuData);
    print('IMU data sent: $imuData');
  }

  // Display a SnackBar popup for detected activity
  void _showActivityPopup(Activity activity) {
    final activityType = activity.type.toString().split('.').last; // Get the activity type as a string
    final activityMessage = 'Detected activity: $activityType with confidence: ${activity.confidence}%';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(activityMessage),
        duration: Duration(milliseconds: 50),
      ),
    );
  }

  // Dispose function to cancel the subscription when done
  void dispose() {
    _activitySubscription?.cancel();
  }
}
import 'dart:async';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';

class ActivityRecognitionService {
  static final ActivityRecognitionService _instance = ActivityRecognitionService._internal();

  factory ActivityRecognitionService() => _instance;

  ActivityRecognitionService._internal();

  final StreamController<Activity> _activityController = StreamController<Activity>.broadcast();
  StreamSubscription<Activity>? _activitySubscription;

  String currentActivity = "Unknown";

  Stream<Activity> get activityStream => _activityController.stream;

  void initialize() async {
    ActivityPermission permission = await FlutterActivityRecognition.instance.checkPermission();
    if (permission == ActivityPermission.DENIED) {
      permission = await FlutterActivityRecognition.instance.requestPermission();
    }

    if (permission == ActivityPermission.GRANTED) {
      _activitySubscription = FlutterActivityRecognition.instance.activityStream.listen(
            (activity) {
          currentActivity = activity.type.toString().split('.').last;
          _activityController.add(activity);
        },
        onError: (error) {
          print("Activity recognition error: $error");
        },
      );
    }
  }

  void dispose() {
    _activitySubscription?.cancel();
    _activityController.close();
  }
}
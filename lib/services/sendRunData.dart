import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> sendRunData({
  required String? username,
  required DateTime startTime,
  required DateTime endTime,
  required double totalDistance,
  required String activityType,
  required List<Map<String, double>> route,
  required Map<dynamic, dynamic> imuData,
  required List<Map<String, dynamic>> checkpoints,
}) async {
  final url = Uri.parse('https://app.dokkedalleth.dk/saveRun.php');

  final body = {
    "username": username,
    "start_time": startTime.toIso8601String(),
    "end_time": endTime.toIso8601String(),
    "total_distance": totalDistance,
    "activity_type": activityType,
    "route": route,
    "imu_data": imuData,
    'checkpoints': checkpoints,
  };
  print("Sending check data: $checkpoints");

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['success']) {
        print("Run data saved successfully! Run ID: ${responseData['run_id']}");
      } else {
        print("Failed to save run data: ${responseData['error']}");
      }
    } else {
      print("Server error: ${response.statusCode}");
    }
  } catch (e) {
    print("Error sending run data: $e");
  }
}
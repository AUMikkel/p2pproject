import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> sendRunData({
  required String? username,
  required DateTime startTime,
  required DateTime endTime,
  required double totalDistance,
  required String activityType,
  required List<Map<String, double>> route,
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
    'checkpoints': checkpoints,
  };

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['success']) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}


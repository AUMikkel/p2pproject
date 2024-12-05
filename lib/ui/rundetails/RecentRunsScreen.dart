import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class RecentRunsScreen extends StatefulWidget {
  @override
  _RecentRunsScreenState createState() => _RecentRunsScreenState();
}

class _RecentRunsScreenState extends State<RecentRunsScreen> {
  List<Map<String, dynamic>> recentRuns = [];
  bool isLoading = true;
  bool hasError = false;
  final Map<int, MapController> mapControllers = {}; // Unique MapControllers
  @override
  void initState() {
    super.initState();
    _fetchRecentRuns(); // Fetch the runs when the widget initializes
  }
  @override
  void dispose() {
    for (var controller in mapControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRecentRuns() async {
    try {
      final response = await http.get(Uri.parse('https://app.dokkedalleth.dk/routes.php'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success']) {
          final allRuns = jsonData['routes'] as List<dynamic>;
          setState(() {
            // Process only the last 10 runs
            recentRuns = _processRuns(allRuns);
            isLoading = false;
          });
        } else {
          setState(() {
            print('Failed to load recent runs: ${jsonData['error']}');
            print('Response: ${response.body}');
            hasError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          print('Failed to load recent runs: ${response.statusCode}');
          print('Response: ${response.body}');
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        print('Failed to load recent runs1: $e');
        hasError = true;
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _processRuns(List<dynamic> runs) {
    // Take the last 10 runs (assuming the list is already sorted)
    final last10Runs = runs.reversed.toList();

    return last10Runs.map((run) {
      final totalTimeInSeconds = run['total_time'] is int
          ? run['total_time']
          : int.tryParse(run['total_time'].toString()) ?? 0;

      final totalDistanceInKm = run['total_distance'] is num
          ? run['total_distance'] / 1000
          : double.tryParse(run['total_distance'].toString()) ?? 0.0;

      String pace = "N/A";
      if (totalDistanceInKm > 0) {
        final paceInSecondsPerKm = totalTimeInSeconds / totalDistanceInKm;
        final paceMinutes = (paceInSecondsPerKm ~/ 60).toString();
        final paceSeconds = (paceInSecondsPerKm % 60).toStringAsFixed(0).padLeft(2, '0');
        pace = '$paceMinutes:$paceSeconds';
      }

      final route = run['route'] is List
          ? (run['route'] as List<dynamic>)
          .map((point) => LatLng(point['lat'], point['lng']))
          .toList()
          : <LatLng>[];

      return {
        'date': run['date'], // Replace with a formatted date if available
        'distance': '${totalDistanceInKm.toStringAsFixed(2)} km',
        'time': _formatTime(totalTimeInSeconds),
        'pace': pace,
        'route': route, // Safe route data
        'checkpoints': run['checkpoints'], // Include checkpoints if needed
      };
    }).toList();
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return const Center(
        child: Text(
          'Failed to load recent runs. Please try again later.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: recentRuns.length,
      itemBuilder: (context, index) {
        final run = recentRuns[index];
        final route = run['route'] as List<LatLng>;
        final mapController = mapControllers.putIfAbsent(index, () => MapController());

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ExpansionTile(
            title: Text("Run on ${run['date']}"),
            subtitle: Text("${run['distance']} in ${run['time']}"),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pace: ${run['pace']}/km",
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const Spacer(),
                        Text(
                          "Checkpoints: ${run['checkpoints']?.length ?? 0}",
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12.0),
                      bottomRight: Radius.circular(12.0),
                    ),
                    child: SizedBox(
                      height: 400, // Adjusted height for map visibility
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: route,
                            padding: const EdgeInsets.all(30),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                            additionalOptions: const {
                              'accessToken':
                              'pk.eyJ1IjoiYXNnZXJsIiwiYSI6ImNtMm9sZDhlaDBpOTcyanM5NjJ0aWx5dmIifQ.R-FjlLExCgUyn_AfAnovWQ',
                              'id': 'mapbox/streets-v11',
                            },
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: route,
                                strokeWidth: 4.0,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: route.first,
                                width: 30,
                                height: 30,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              Marker(
                                point: route.last,
                                width: 30,
                                height: 30,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
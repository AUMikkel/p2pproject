import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RecentRunsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Placeholder list of recent runs with additional details
    final List<Map<String, dynamic>> recentRuns = [
      {
        'date': 'Oct 29, 2024',
        'distance': '5.2 km',
        'time': '25:30',
        'pace': '4:55/km',
        'elevationGain': '150 m',
        'route': [
          LatLng(37.7749, -122.4194),
          LatLng(37.7849, -122.4094),
          LatLng(37.7959, -122.4500),
        ],
      },
      {
        'date': 'Oct 28, 2024',
        'distance': '4.0 km',
        'time': '22:15',
        'pace': '5:34/km',
        'elevationGain': '120 m',
        'route': [
          LatLng(37.7749, -122.4194),
          LatLng(37.7849, -122.4094),
          LatLng(37.7949, -122.3994),
        ],
      },
      {
        'date': 'Oct 27, 2024',
        'distance': '6.1 km',
        'time': '30:45',
        'pace': '5:02/km',
        'elevationGain': '200 m',
        'route': [
          LatLng(37.7649, -122.4294),
          LatLng(37.7749, -122.4194),
          LatLng(37.7849, -122.4094),
        ],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: recentRuns.length,
      itemBuilder: (context, index) {
        final run = recentRuns[index];
        final route = run['route'] as List<LatLng>;
        final MapController controller = MapController();

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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Pace: ${run['pace']}",
                            style: const TextStyle(fontSize: 16,color: Colors.black)
                            ),
                        const Spacer(),
                        Text("Elevation Gain: ${run['elevationGain']}",
                            style: const TextStyle(fontSize: 16, color: Colors.black)
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
                        mapController: controller,
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: route, // Fit camera to route coordinates
                            padding: const EdgeInsets.all(30), // Add padding around route
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none, // Disable user interactions
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
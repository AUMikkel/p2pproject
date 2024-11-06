import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RunDetailsScreen extends StatelessWidget {
  final String runDetails;

  const RunDetailsScreen({super.key, required this.runDetails});

  @override
  Widget build(BuildContext context) {
    // Dummy list of locations (latitude, longitude)
    final List<LatLng> route = [
      const LatLng(37.7749, -122.4194), // Start point
      const LatLng(37.7849, -122.4094),
      const LatLng(37.7949, -122.3994), // End point
    ];


    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Details'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(runDetails),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                coordinates: route, // Fit camera to route coordinates
                padding: EdgeInsets.all(70)
                )
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                  additionalOptions: const {
                    'accessToken': 'pk.eyJ1IjoiYXNnZXJsIiwiYSI6ImNtMm9sZDhlaDBpOTcyanM5NjJ0aWx5dmIifQ.R-FjlLExCgUyn_AfAnovWQ',
                    'id': 'mapbox/streets-v11',
                  },
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 5.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Start Point Marker with Tooltip
                    Marker(
                      point: route.first,
                      width: 40,
                      height: 40,
                      child: const Tooltip(
                        message: 'Start Point',
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 30.0,
                        ),
                      ),
                    ),
                    // Goal Point Marker with Tooltip
                    Marker(
                      point: route.last,
                      width: 40,
                      height: 40,
                      child: const Tooltip(
                        message: 'Goal Point',
                        child: Icon(
                          Icons.flag,
                          color: Colors.green,
                          size: 30.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
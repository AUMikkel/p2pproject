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
      LatLng(37.7749, -122.4194), // San Francisco
      LatLng(37.7849, -122.4094),
      LatLng(37.7949, -122.3994),
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
                initialCenter: route[0],
                initialZoom: 14.0,
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
                  markers: route
                      .map((location) => Marker(
                    point: location,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                    ),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
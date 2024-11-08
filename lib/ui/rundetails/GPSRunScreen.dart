import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_activity_recognition/models/activity.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../../services/ActivityRecognitionService.dart';

class GPSRunScreen extends StatefulWidget {
  @override
  _RecordRunScreenState createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends State<GPSRunScreen> {
  final Location _location = Location();
  late final ActivityRecognitionService _activityService;
  bool _isRecording = false;
  bool _isLoadingLocation = true;
  ValueNotifier<List<LatLng>> _route = ValueNotifier<List<LatLng>>([]);
  ValueNotifier<LatLng?> _currentLocation = ValueNotifier<LatLng?>(null);
  ValueNotifier<String> _currentActivity = ValueNotifier<String>("Unknown");
  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<Activity>? _activitySubscription;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _activityService = ActivityRecognitionService();

    // Listen to shared activity updates
    _activitySubscription = _activityService.activityStream.listen((activity) {
      if (!_isDisposed) {
        _currentActivity.value = activity.type.toString().split('.').last;
      }
    });

    _getInitialLocation();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationSubscription?.cancel();
    _activitySubscription?.cancel();
    _route.dispose();
    _currentLocation.dispose();
    _currentActivity.dispose();
    super.dispose();
  }

  Future<void> _getInitialLocation() async {
    if (await _location.requestPermission() == PermissionStatus.granted) {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        _currentLocation.value = LatLng(locationData.latitude!, locationData.longitude!);
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _locationSubscription?.cancel();
      setState(() => _isRecording = false);
    } else {
      _locationSubscription = _location.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          LatLng point = LatLng(locationData.latitude!, locationData.longitude!);
          _currentLocation.value = point;
          _route.value = [..._route.value, point];
        }
      });
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record a New Run'),
      ),
      body: Stack(
        children: [
          if (_isLoadingLocation)
            Center(child: CircularProgressIndicator())
          else
            ValueListenableBuilder<LatLng?>(
              valueListenable: _currentLocation,
              builder: (context, currentLocation, _) {
                if (currentLocation == null) {
                  return Center(
                    child: Text(
                      'Unable to fetch location',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }
                return FlutterMap(
                  options: MapOptions(
                    initialCenter: currentLocation,
                    initialZoom: 17,
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
                    ValueListenableBuilder<List<LatLng>>(
                      valueListenable: _route,
                      builder: (context, route, _) {
                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route,
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                          ],
                        );
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80,
                          height: 80,
                          point: currentLocation,
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: ValueListenableBuilder<String>(
              valueListenable: _currentActivity,
              builder: (context, activity, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Current Activity: $activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _toggleRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
              ),
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ),
        ],
      ),
    );
  }
}
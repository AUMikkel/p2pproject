import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_activity_recognition/models/activity.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/ActivityRecognitionService.dart';
import '../../services/sendRunData.dart';
import 'package:http/http.dart' as http;
import '../shared/UserSession.dart';
import 'package:flutter_tts/flutter_tts.dart';

class GPSRunScreen extends StatefulWidget {
  @override
  _GPSRunScreenState createState() => _GPSRunScreenState();
}

class _GPSRunScreenState extends State<GPSRunScreen> {
  final Location _location = Location();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Initialize the audio player
  late final ActivityRecognitionService _activityService;
  List<Map<String, dynamic>> _checkpoints = [];
  bool _isRecording = false;
  bool _isLoadingLocation = true;

  ValueNotifier<List<LatLng>> _route = ValueNotifier<List<LatLng>>([]);
  ValueNotifier<LatLng?> _currentLocation = ValueNotifier<LatLng?>(null);
  ValueNotifier<String> _currentActivity = ValueNotifier<String>("Unknown");

  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<Activity>? _activitySubscription;
  FlutterTts _flutterTts = FlutterTts();
  Stopwatch _stopwatch = Stopwatch(); // Track elapsed time
  double _totalDistance = 0.0; // Track total distance in kilometers
  double _paceThreshold = 7.0; // Threshold pace in minutes per kilometer

  bool _isDisposed = false;
  void _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setSpeechRate(0.5); // Slower speech rate
  }
  Future<void> _speak(String message) async {
    await _flutterTts.stop(); // Stop any ongoing speech before starting new
    await _flutterTts.speak(message);
  }
  StreamSubscription<LocationData>? _continuousLocationSubscription;
  @override
  void initState() {
    super.initState();
    _activityService = ActivityRecognitionService();
    _initializeTts();
    // Listen to shared activity updates
    _activitySubscription = _activityService.activityStream.listen((activity) {
      if (!_isDisposed) {
        _currentActivity.value = activity.type.toString().split('.').last;
      }
    });
    _startContinuousLocationUpdates();
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
    _stopwatch.stop();
    _continuousLocationSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }
  Future<void> _startContinuousLocationUpdates() async {
    // Ensure location permissions are granted
    if (await _location.requestPermission() == PermissionStatus.granted) {
      _continuousLocationSubscription = _location.onLocationChanged.listen(
            (locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            LatLng newLocation = LatLng(locationData.latitude!, locationData.longitude!);

            // Update the current location
            if (!_isRecording) {
              // Only update the current location when not recording
              setState(() {
                _currentLocation.value = newLocation;
              });
            }
          }
        },
      );
    }
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

  Future<List<Map<String, dynamic>>> _fetchGhostRoutes() async {
    // Example API call to get routes
    final response = await http.get(Uri.parse('https://app.dokkedalleth.dk/routes.php'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body); // Parse JSON response
      if (jsonData['success'] == true && jsonData['routes'] is List) {
        // Extract the "routes" list from the JSON response
        return List<Map<String, dynamic>>.from(jsonData['routes']);
      } else {
        throw Exception('Invalid data format or no routes found.');
      }
    } else {
      throw Exception('Failed to load ghost routes: ${response.statusCode}');
    }
  }

  String? _selectedGhostRouteId;
  Map<String, dynamic>? _selectedGhostData;

  Future<void> _selectGhostRoute() async {
    final routes = await _fetchGhostRoutes();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return ListTile(
              title: Text('Route ${route['id']} - ${route['total_distance']} m, ${(route['total_time']/60).toStringAsFixed(2)} min'),
              subtitle: Text('By ${route['username']}'),
              onTap: () {
                setState(() {
                  _selectedGhostRouteId = route['id']?.toString(); // Safely convert to String
                  _selectedGhostData = {
                    ...route,
                    'checkpoints': route['checkpoints'] ?? []
                  }; // Store selected route data

                  // Calculate pace threshold (in minutes per kilometer)
                  double ghostTimeInMinutes = route['total_time'] / 60.0; // Convert seconds to minutes
                  double ghostDistanceInKm = route['total_distance'] / 1000.0; // Convert meters to kilometers
                  if (ghostDistanceInKm > 0) {
                    _paceThreshold = ghostTimeInMinutes / ghostDistanceInKm;
                    print("Pace threshold set to $_paceThreshold min/km");
                  }
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
  String? _ghostProgressMessage;

  int _currentGhostCheckpointIndex = 0; // Track the current checkpoint
  bool _isRunCompleted = false; // Flag to indicate race completion

  void _compareWithGhost(LatLng userLocation, int userElapsedTime) {
    if (_selectedGhostData == null) return;

    final ghostCheckpoints = _selectedGhostData!['checkpoints'];
    if (ghostCheckpoints == null || ghostCheckpoints.isEmpty) {
      setState(() {
        _ghostProgressMessage = 'This ghost route has no checkpoints.';
      });
      return;
    }

    // Check if all checkpoints are completed
    if (_currentGhostCheckpointIndex >= ghostCheckpoints.length) {
      if (!_isRunCompleted) {
        setState(() {
          _ghostProgressMessage = 'Run completed! All checkpoints passed.';
          _isRunCompleted = true; // Mark the run as completed
          print('Run completed! All checkpoints passed.');
        });
      }
      return;
    }

    final checkpoint = ghostCheckpoints[_currentGhostCheckpointIndex];
    final checkpointLatLng = LatLng(checkpoint['lat'], checkpoint['lng']);
    final ghostTime = checkpoint['time'];

    final distanceToCheckpoint =
    const Distance().as(LengthUnit.Meter, userLocation, checkpointLatLng);

    if (distanceToCheckpoint < 10) {
      final timeDifference = userElapsedTime - ghostTime;

      setState(() {
        if (timeDifference > 0) {
          print('You are behind by $timeDifference seconds.');
          _ghostProgressMessage = 'You are behind by $timeDifference seconds.';
          final message = 'You are behind by $timeDifference seconds.';
          print(message);
          _ghostProgressMessage = message;
          _speak(message);
        } else {
          print('You are ahead by ${timeDifference.abs()} seconds.');
          final message = 'You are ahead by ${timeDifference.abs()} seconds.';
          print(message);
          _ghostProgressMessage = message;
          _speak(message);
        }
      });

      // Move to the next checkpoint
      _currentGhostCheckpointIndex++;
    }
  }

  void resetRecordingState() {
    setState(() {
      _isRecording = false; // Stop recording
      _route.value = []; // Clear the recorded route
      _checkpoints = []; // Clear checkpoints
      _totalDistance = 0.0; // Reset total distance
      _currentGhostCheckpointIndex = 0; // Reset ghost checkpoint index
      _isRunCompleted = false; // Reset completion status
      _ghostProgressMessage = null; // Clear ghost progress message
      _selectedGhostRouteId = null; // Clear ghost route selection
      _selectedGhostData = null; // Clear ghost data
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording


      _locationSubscription?.cancel();
      _stopwatch.stop();
      setState(() => _isRecording = false);

      // Prepare run data for saving
      final routeData = _route.value.map((point) {
        return {"lat": point.latitude, "lng": point.longitude};
      }).toList();

      final imuData = {};
      final userSession = UserSession();
      final userData = await userSession.getUserData();
      final username = userData['username'];

      // Send run data to the server
      final result = sendRunData(
        username: username,
        startTime: DateTime.now().subtract(Duration(seconds: _stopwatch.elapsed.inSeconds)),
        endTime: DateTime.now(),
        totalDistance: _totalDistance,
        activityType: _currentActivity.value,
        route: routeData,
        imuData: imuData,
        checkpoints: _checkpoints,
      );
      if (await result) {
        showDialog(context: context,
            builder: (context) => const AlertDialog(
                title: Text('Run saved successfully.',
                  style: TextStyle(color: Colors.white),)));
      } else {
        showDialog(context: context,
            builder: (context) => const AlertDialog(
                title: Text('Failed to save run.',style:
                TextStyle(color: Colors.white),)));
      }
      resetRecordingState();
    } else {
      // Start recording
      _stopwatch.start();
      _locationSubscription = _location.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {

          LatLng newPoint = LatLng(locationData.latitude!, locationData.longitude!);
          if (_route.value.isNotEmpty) {
            double distanceIncrement = _calculateDistance(_route.value.last, newPoint);

            // Update total distance and UI
            setState(() {
              _totalDistance += distanceIncrement; // Increment total distance
            });
            if (_checkpoints.isEmpty || _calculateDistance(LatLng(_checkpoints.last['lat'], _checkpoints.last['lng'],),
                    newPoint) >
                    30) { // 30 meter
              _checkpoints.add({
                'lat': newPoint.latitude,
                'lng': newPoint.longitude,
                'time': _stopwatch.elapsed.inSeconds,
              });
            }
            _totalDistance += _calculateDistance(_route.value.last, newPoint);

            // Compare with ghost at each point
            if (_selectedGhostData != null) {
              print('Comparing with ghost...');
              _compareWithGhost(newPoint, _stopwatch.elapsed.inSeconds);
            }
          }
          _currentLocation.value = newPoint;
          _route.value = [..._route.value, newPoint];

          _checkPaceAndUpdateDisplay();
        }
      });
      setState(() => _isRecording = true);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2); // Distance in meters
  }
  ValueNotifier<String> _currentPace = ValueNotifier<String>("N/A min/km");
  void _checkPaceAndUpdateDisplay() {
    if (_totalDistance > 0) {
      double totalDistanceInKm = _totalDistance / 1000.0; // Convert meters to kilometers
      double elapsedMinutes = _stopwatch.elapsed.inSeconds / 60.0;

      // Avoid division by zero
      if (totalDistanceInKm > 0) {
        double pace = elapsedMinutes / totalDistanceInKm; // Pace in minutes per kilometer
        String paceFormatted = "${pace.floor()}:${((pace % 1) * 60).toStringAsFixed(0).padLeft(2, '0')} min/km";

        // Update the current pace
        _currentPace.value = paceFormatted;
      } else {
        _currentPace.value = "N/A min/km";
      }
    } else {
      _currentPace.value = "N/A min/km";
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    if (_selectedGhostData != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _selectedGhostData!['route']
                                .map<LatLng>((point) =>
                                LatLng(point['lat'], point['lng']))
                                .toList(),
                            strokeWidth: 4,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80,
                          height: 80,
                          point: currentLocation,
                          child: const Icon(
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
            child: Column(
              children: [
                /*ValueListenableBuilder<String>(
                  valueListenable: _currentActivity,
                  builder: (context, activity, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Current Activity: $activity\nTotal Distance: ${_totalDistance.toStringAsFixed(2)} m',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),*/
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _selectGhostRoute,
                  child: Text(
                    _selectedGhostData != null
                        ? 'Racing Against Route: ${_selectedGhostData!['id'].toString()}' // Convert to String
                        : 'Select Ghost Route',
                  ),
                ),
                if (_selectedGhostData != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_ghostProgressMessage != null)
                            Text(
                              _ghostProgressMessage!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Ghost Pace: ${_paceThreshold.toStringAsFixed(2)} min/km\n' +
                                'Current Pace: ${_currentPace.value}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
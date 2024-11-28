import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_activity_recognition/models/activity.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/ActivityRecognitionService.dart';
import '../../services/BleNotificationService.dart';
import '../rundetails/BleScanConnectionScreen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/sendRunData.dart';
import 'package:http/http.dart' as http;
import '../shared/UserSession.dart';
import '../../sensors/IMUReader.dart';

class GPSRunScreen extends StatefulWidget {
  @override
  _GPSRunScreenState createState() => _GPSRunScreenState();
}

class _GPSRunScreenState extends State<GPSRunScreen> {
  final IMUReader imuReader = IMUReader();
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
  StreamSubscription<List<double>>? _accelerometerSubscription;
  StreamSubscription<List<double>>? _gyroscopeSubscription;
  StreamSubscription<List<double>>? _magnetometerSubscription;

  Stopwatch _stopwatch = Stopwatch(); // Track elapsed time
  double _totalDistance = 0.0; // Track total distance in kilometers
  double _paceThreshold = 7.0; // Threshold pace in minutes per kilometer

  bool _isDisposed = false;
  bool _isBleConnected = false;

  // Text for the button at then buttom of the screen
  String _buttonText = 'Start Run';

  StreamSubscription<LocationData>? _continuousLocationSubscription;
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

    _checkBleConnection();
    _startContinuousLocationUpdates();
    _getInitialLocation();

    // Listen to IMU data streams
    _accelerometerSubscription = imuReader.accelerometerStream.listen((data) {
      // Process accelerometer data
      print('Accelerometer: $data');
    });
    _gyroscopeSubscription = imuReader.gyroscopeStream.listen((data) {
      // Process gyroscope data
      print('Gyroscope: $data');
    });
    _magnetometerSubscription = imuReader.magnetometerStream.listen((data) {
      // Process magnetometer data
      print('Magnetometer: $data');
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationSubscription?.cancel();
    _activitySubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    imuReader.dispose();
    _route.dispose();
    _currentLocation.dispose();
    _currentActivity.dispose();
    _stopwatch.stop();
    _continuousLocationSubscription?.cancel();
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

  Future<void> _checkBleConnection() async {
    // Implement your logic to check if the BLE device is connected
    // For example, you can use a service or a method that returns the connection status
    bool isConnected = await checkBleConnectionStatus();
    setState(() {
      _isBleConnected = isConnected;
    });

    if (!_isBleConnected) {
      _showBleConnectionPrompt();
    }
  }

  Future<bool> checkBleConnectionStatus() async {
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
    for (BluetoothDevice device in connectedDevices) {
      if (device.name == 'M5UiFlow') {
        return true;
      }
    }
    return false;
  }

  void _showBleConnectionPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Connected to Bluetooth Device',
          style: TextStyle(color: Colors.white)),
        content: const Text('Please connect to your Bluetooth device to continue.',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => BleScanConnectionScreen()),
              );
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
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
        print(response.body);
        print('Fetched ${jsonData['routes'].length} ghost routes.');
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
              title: Text('Route ${route['id']} - ${route['total_distance']} m'),
              subtitle: Text('By ${route['username']}'),
            onTap: () {
            print("Route ID type: ${route['id'].runtimeType}"); // Debug type
            setState(() {
            _selectedGhostRouteId = route['id']?.toString(); // Safely convert to String
            _selectedGhostData = {
              ...route,
              'checkpoints': route['checkpoints'] ?? []
            }; // Store selected route data
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
/*
  void _compareWithGhost(LatLng userLocation, int userElapsedTime) {
    if (_selectedGhostData == null) return;

    final ghostCheckpoints = _selectedGhostData!['checkpoints'];
    if (ghostCheckpoints == null) {
      setState(() {
        _ghostProgressMessage = 'This ghost route has no checkpoints.';
      });
      return;
    }
    for (var checkpoint in ghostCheckpoints) {
      final checkpointLatLng = LatLng(checkpoint['lat'], checkpoint['lng']);
      final ghostTime = checkpoint['time'];

      final distanceToCheckpoint =
      const Distance().as(LengthUnit.Meter, userLocation, checkpointLatLng);

      if (distanceToCheckpoint < 25) {
        final timeDifference = userElapsedTime - ghostTime;

        setState(() {
          if (timeDifference > 0) {
            print('You are behind by $timeDifference seconds.');
            _ghostProgressMessage = 'You are behind by $timeDifference seconds.';
          } else {
            print('You are ahead by $timeDifference seconds.');
            _ghostProgressMessage =
            'You are ahead by ${timeDifference.abs()} seconds.';
          }
        });
        break;
      }
    }
  }*/

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
          _audioPlayer.play(AssetSource('behind.wav'));
        } else {
          print('You are ahead by ${timeDifference.abs()} seconds.');
          _ghostProgressMessage =
          'You are ahead by ${timeDifference.abs()} seconds.';
          _audioPlayer.play(AssetSource('pacesound.wav'));
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
      _stopRecording();
    } else {
      // Start recording
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // Wait for the "Run started" message
    await _waitForRunStartedMessage();

    // Start logging location data
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
          if (_checkpoints.isEmpty || _calculateDistance(LatLng(_checkpoints.last['lat'], _checkpoints.last['lng']),
              newPoint) > 30) { // 30 meter
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
          _checkPaceAndPlaySound();
        }
        _currentLocation.value = newPoint;
        _route.value = [..._route.value, newPoint];
      }
    });

    // Listen for the "Run finished" message
    BleNotificationService().receivedMessagesStream.listen((message) {
      if (message.contains("Run finished")) {
        _stopRecording();
      }
    });

    // Start listening to IMU data
    await BleNotificationService().startListeningToIMUData();

    // Start recording logic
    setState(() {
      _isRecording = true;
      _buttonText = 'Stop Run';
    });
  }

  void _stopRecording() {
    _locationSubscription?.cancel();
    _stopwatch.stop();
    setState(() {
      _isRecording = false;
      _buttonText = 'Start Run';
    });

    // Stop listening to IMU data
    BleNotificationService().stopListeningToIMUData();

    // Save run data or send it to the server
    final routeData = _route.value.map((point) {
      return {"lat": point.latitude, "lng": point.longitude};
    }).toList();

    final imuData = {}; // Replace with actual IMU data if collected
    final userSession = UserSession();
    userSession.getUserData().then((userData) {
      print('Sending run data:');
      print({
        'username': userData['username'], // Replace with actual user ID
        'start_time': DateTime.now()
            .subtract(Duration(seconds: _stopwatch.elapsed.inSeconds))
            .toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'total_distance': _totalDistance,
        'activity_type': _currentActivity.value,
        'checkpoints': _checkpoints,
      });
      print('User data: $userData');
      String? username = userData['username']; // Debug log
      sendRunData(
        username: username, // Replace with actual user ID
        startTime: DateTime.now().subtract(Duration(seconds: _stopwatch.elapsed.inSeconds)),
        endTime: DateTime.now(),
        totalDistance: _totalDistance,
        activityType: _currentActivity.value,
        route: routeData,
        imuData: imuData,
        checkpoints: _checkpoints,
      );
      resetRecordingState();
    });
  }

  Future<void> _waitForRunStartedMessage() async {
    Completer<void> completer = Completer<void>();
    StreamSubscription<String>? subscription;

    subscription = BleNotificationService().receivedMessagesStream.listen((message) {
      if (message.contains("Run started")) {
        completer.complete();
        subscription?.cancel();
      }
    });
    await completer.future; // Wait for the completer to complete
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2); // Distance in meters
  }

  void _checkPaceAndPlaySound() {
    if (_totalDistance > 0) {
      double elapsedMinutes = _stopwatch.elapsed.inSeconds / 60;
      double pace = elapsedMinutes / _totalDistance; // Pace in minutes per kilometer

      if (pace > _paceThreshold) {
        _playSlowPaceAlert();
      }
    }
  }

  Future<void> _playSlowPaceAlert() async {
    await _audioPlayer.play(AssetSource('pacesound.wav')); // Play alert sound
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
            child: Column(
              children: [
                ValueListenableBuilder<String>(
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
                ),
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
                      child: Text(
                        _ghostProgressMessage ??
                            'Start racing to compare with the ghost!',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,color: Colors.red),
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
              child: Text(_isRecording ? 'Stop Run' : 'Start Recording'),
            ),
          ),
        ],
      ),
    );
  }
}
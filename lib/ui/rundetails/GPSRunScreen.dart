import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
import 'package:flutter_tts/flutter_tts.dart';
import '../../sensors/IMUReader.dart';
import '../../utils/KalmanFilter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class GPSRunScreen extends StatefulWidget {
  @override
  _GPSRunScreenState createState() => _GPSRunScreenState();
}

class _GPSRunScreenState extends State<GPSRunScreen> {
  final IMUReader imuReader = IMUReader();
  late final KalmanFilter _kalmanFilter;
  final Location _location = Location();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Initialize the audio player
  late final ActivityRecognitionService _activityService;
  List<Map<String, dynamic>> _checkpoints = [];
  bool _isRecording = false;
  bool _isWaitingForStartSignal = false; // Add this line
  bool _isLoadingLocation = true;

  ValueNotifier<List<LatLng>> _route = ValueNotifier<List<LatLng>>([]);
  ValueNotifier<LatLng?> _currentLocation = ValueNotifier<LatLng?>(null);
  ValueNotifier<String> _currentActivity = ValueNotifier<String>("Unknown");

  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<Activity>? _activitySubscription;
  StreamSubscription<Map<String, dynamic>>? _accelerometerSubscription;
  StreamSubscription<Map<String, dynamic>>? _bleIMUDataSubscription;


  FlutterTts _flutterTts = FlutterTts();
  Stopwatch _stopwatch = Stopwatch(); // Track elapsed time
  double _totalDistance = 0.0; // Track total distance in kilometers
  double _paceGhost = 7.0; // Threshold pace in minutes per kilometer

  bool _isDisposed = false;
  bool _isBleConnected = false;

  // Text for the button at then buttom of the screen
  String _buttonText = 'Start Run'; // Initialize button text

  void _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setSpeechRate(1.0); // Slower speech rate
  }
  Future<void> _speak(String message) async {
    await _flutterTts.stop(); // Stop any ongoing speech before starting new
    await _flutterTts.speak(message);
  }

  Future<Directory?> getLogDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError("This platform is not supported");
    }
  }
  StreamSubscription<LocationData>? _continuousLocationSubscription;

  LatLng? _previousLocation; // Define _previousLocation
  int? _previousTimestamp; // Define _previousTimestamp

  // Add these variables to your _GPSRunScreenState class
  List<String> _logEntries = [];

  // Buffers for IMU data
  Map<int, List<double>> _mobileIMUBuffer = {};
  Map<int, List<double>> _bleIMUBuffer = {};

  ValueNotifier<double> _currentPace = ValueNotifier<double>(0.0);
  ValueNotifier<double> _currentVelocity = ValueNotifier<double>(0.0);

  int? _lastTimestamp;

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
    _initializeTts();
    _checkBleConnection();
    _startContinuousLocationUpdates();
    _getInitialLocation();


    _accelerometerSubscription = imuReader.accelerometerStream.listen((data) {
      if (_isRecording){
        //print('IMU Data mobile: ${data['data']}');
        int timestamp = data['timestamp'];
        _mobileIMUBuffer[timestamp] = data['data'];
        _combineIMUData(timestamp);
      }
    });

    _bleIMUDataSubscription = BleNotificationService().imuDataStream.listen((data) {
      if (_isRecording) {
        //print('IMU Data ble: ${data['data']}');
        // Assuming that it has the right unit
        // Convert raw readings (in LSBs) to m/s2m/s2: Acceleration in m/s²=(Raw reading)×(Sensitivity Scale Factor)×9.8Acceleration in m/s²=(Raw reading)×(Sensitivity Scale Factor)×9.8.
        int timestamp = data['timestamp'];
        _bleIMUBuffer[timestamp] = _parseIMUData(data['data']);
        _combineIMUData(timestamp);
      }
    });

  }

  // Function to log data
  void _logData(double pace, double velocity, double distance) {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    String logEntry = 'Timestamp: $timestamp, Pace: ${pace} min/km, Velocity: ${velocity} m/s, Distance: ${distance} m';
    _logEntries.add(logEntry);
    print(logEntry); // Optional: Print log entry to console
  }

// Function to save log to a file
  Future<void> _saveLogToFile() async {
    try {
      final directory = await getLogDirectory();
      if (directory == null) {
        throw Exception("Unable to determine directory");
      }
      //add a timestamp to the file name
      final file = File('${directory.path}/run_log.txt');
      await file.writeAsString(_logEntries.join('\n'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log saved to ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save log: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _combineIMUData(int timestamp) {
    const int imuFrequencyHz = 50; // Frequency of your IMU for the mobile device
    final int tolerance = (1 / imuFrequencyHz * 1000000).toInt(); // Tolerance in microseconds
    const int propagationDelay = 62598; // Propagation delay in microseconds

    // Only proceed if there is data in the BLE IMU buffer
    if (_bleIMUBuffer.isEmpty) {
      return;
    }

    int adjustedTimestamp = timestamp - propagationDelay;

    int? closestTimestamp;
    int minDifference = tolerance;

    // Find the closest timestamp in the mobile IMU buffer
    for (int t in _mobileIMUBuffer.keys) {
      int difference = (t - adjustedTimestamp).abs();
      if (difference <= tolerance && difference < minDifference) {
        minDifference = difference;
        closestTimestamp = t;
      }
    }
    // If a matching timestamp is found, combine the IMU data
    if (closestTimestamp != null && _bleIMUBuffer.containsKey(closestTimestamp)) {
      List<double> imuDataMobile = _mobileIMUBuffer.remove(closestTimestamp)!;
      List<double> imuDataBle = _bleIMUBuffer.remove(closestTimestamp)!;
      _handleIMUData(imuDataMobile, imuDataBle, closestTimestamp);

      // Remove all IMU readings before the matching timestamp
      _mobileIMUBuffer.removeWhere((key, value) => key < closestTimestamp!);
      _bleIMUBuffer.removeWhere((key, value) => key < closestTimestamp!);
    }
  }

  double _getDeltaTime(int timestamp) {
    if (_lastTimestamp == null) {
      _lastTimestamp = timestamp;
      return 0.0;
    }
    double deltaTime = (timestamp - _lastTimestamp!) / 1000000.0;
    _lastTimestamp = timestamp;
    return deltaTime;
  }

  void _handleIMUData(List<double> imuDataMobile, List<double> imuDataBle, int timestamp) {
    double deltaTime = _getDeltaTime(timestamp);
    print('DeltaTime: $deltaTime s');
    // Weighted averaging of IMU data
    double weightMobile = 1.0; // Adjust weights as needed
    double weightBle = 0.0;
    List<double> fusedIMUData = [
      weightMobile * imuDataMobile[0] + weightBle * imuDataBle[0], // ax
      weightMobile * imuDataMobile[1] + weightBle * imuDataBle[1]  // ay
    ];

    _kalmanFilter.predict(fusedIMUData, deltaTime);
  }

  List<double> _parseIMUData(String message) {
    // Remove parentheses and split the string by commas
    List<String> parts = message.replaceAll('(', '').replaceAll(')', '').split(',');
    return parts.map((part) {
      try {
        return double.parse(part);
      } catch (e) {
        print('Error parsing double: $part');
        return 0.0; // Default value in case of error
      }
    }).toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationSubscription?.cancel();
    _activitySubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _bleIMUDataSubscription?.cancel();
    imuReader.dispose();
    _route.dispose();
    _currentLocation.dispose();
    _currentActivity.dispose();
    _stopwatch.stop();
    _continuousLocationSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _startContinuousLocationUpdates() async {
    if (await _location.requestPermission() == PermissionStatus.granted) {
      _continuousLocationSubscription = _location.onLocationChanged.listen(
            (locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            LatLng newLocation = LatLng(locationData.latitude!, locationData.longitude!);
            int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

            if (!_isRecording) {
              setState(() {
                _currentLocation.value = newLocation;
                //_kalmanFilter = KalmanFilter(_currentLocation.value!); // Reset KalmanFilter for a new recording
                // Reset the KalmanFilter
                _kalmanFilter.reset();
                // Reinitialize the KalmanFilter
                _kalmanFilter.reinitialize();
                _currentVelocity.value = 0.0;
                _currentPace.value = 0.0;
              });
            } else {
              double vx = 0.0;
              double vy = 0.0;

              if (_previousLocation != null && _previousTimestamp != null) {
                double deltaTime = (currentTimestamp - _previousTimestamp!) / 1000.0;
                double distance = const Distance().as(LengthUnit.Meter, _previousLocation!, newLocation);
                double bearing = const Distance().bearing(_previousLocation!, newLocation);

                vx = (distance / deltaTime) * cos(bearing * pi / 180.0);
                vy = (distance / deltaTime) * sin(bearing * pi / 180.0);
              }

              _kalmanFilter.updateWithGPS(newLocation, vx, vy);
              _previousLocation = newLocation;
              _previousTimestamp = currentTimestamp;
              double speed = sqrt(vx*vx + vy*vy);
              double pace = (speed > 0.0) ? (1000 / speed) / 60 : 0;
              if (pace.isFinite && pace > 0) {
                _currentPace.value = pace;
              } else {
                _currentPace.value = 0.0;
              }
              _currentVelocity.value = speed;

              // Log the data's pace, speed, and distance
              _logData(pace, speed, _totalDistance);

              // Send pace to BLE device
              //print('Sending pace to BLE device...');
              BleNotificationService().sendPaceToBleDevice(_currentPace.value, _paceGhost);
            }
          }
        },
      );
    }
  }

  Future<void> _checkBleConnection() async {
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
          _kalmanFilter = KalmanFilter(_currentLocation.value!); // Initialize KalmanFilter
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
                    _paceGhost = ghostTimeInMinutes / ghostDistanceInKm;
                    //print("Pace threshold set to $_paceGhost min/km");
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
          //print('Run completed! All checkpoints passed.');
        });
      }
      return;
    }

    final checkpoint = ghostCheckpoints[_currentGhostCheckpointIndex];
    final checkpointLatLng = LatLng(checkpoint['lat'], checkpoint['lng']);
    final ghostTime = checkpoint['time'];

    final distanceToCheckpoint =
    const Distance().as(LengthUnit.Meter, userLocation, checkpointLatLng);

    if (distanceToCheckpoint < 5) {
      final timeDifference = userElapsedTime - ghostTime;

      setState(() {
        if (timeDifference > 0) {
          //print('You are behind by $timeDifference seconds.');
          _ghostProgressMessage = 'You are behind by ${timeDifference.abs()}. seconds.';
          final message = 'You are behind by ${timeDifference.abs()} seconds.';
          _ghostProgressMessage = message;
          _speak(message);
        } else {
          print('You are ahead by ${timeDifference.abs()} seconds.');
          final message = 'You are ahead by ${timeDifference.abs()} seconds.';
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
      _stopRecording();
    } else {
      // Start recording
      setState(() {
        _isWaitingForStartSignal = true; // Set waiting state
        _buttonText = 'Waiting for start signal'; // Update button text
      });
      await _startRecording();
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
            ////print('Comparing with ghost...');
            _compareWithGhost(newPoint, _stopwatch.elapsed.inSeconds);
          }
          _checkPaceAndUpdateDisplay();
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
      _isWaitingForStartSignal = false; // Reset waiting state
      _buttonText = 'Stop Run';
    });
  }

  Future<void> _stopRecording() async {
    _locationSubscription?.cancel();
    _stopwatch.stop();
    setState(() {
      _isRecording = false;
      _buttonText = 'Start Run';
    });

    // Stop listening to IMU data
    BleNotificationService().stopListeningToIMUData();

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

    // Save the log file
    _saveLogToFile();
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
  ValueNotifier<String> _currentPacestring = ValueNotifier<String>("N/A min/km");
  void _checkPaceAndUpdateDisplay() {

    if (_totalDistance > 0) {
      double totalDistanceInKm = _totalDistance / 1000.0; // Convert meters to kilometers
      double elapsedMinutes = _stopwatch.elapsed.inSeconds / 60.0;

      // Avoid division by zero
      if (totalDistanceInKm > 0) {
        double pace = elapsedMinutes / totalDistanceInKm; // Pace in minutes per kilometer
        String paceFormatted = "${pace.floor()}:${((pace % 1) * 60).toStringAsFixed(0).padLeft(2, '0')} min/km";

        // Update the current pace
        _currentPacestring.value = paceFormatted;
      } else {
        _currentPacestring.value = "N/A min/km";
      }
    } else {
      _currentPacestring.value = "N/A min/km";
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
                ValueListenableBuilder<String>(
                  valueListenable: _currentActivity,
                  builder: (context, activity, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Activity: $activity',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            ValueListenableBuilder<double>(
                              valueListenable: _currentPace,
                              builder: (context, pace, _) {
                                return Text(
                                  'Current Pace: ${pace.toStringAsFixed(3)} min/km',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                );
                              },
                            ),
                            ValueListenableBuilder<double>(
                              valueListenable: _currentVelocity,
                              builder: (context, velocity, _) {
                                return Text(
                                  'Current Velocity: ${velocity.toStringAsFixed(3)} m/s',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Total Distance: ${_totalDistance.toStringAsFixed(2)} m',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
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
                            'Ghost Pace: ${_paceGhost.toStringAsFixed(2)} min/km\n' +
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
              child: Text(_buttonText),
            ),
          ),
          const SizedBox(height: 8), // Add some spacing between the buttons
          ElevatedButton(
            onPressed: _saveLogToFile,
            child: Text('Save Log File'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import '../profile/StatsScreen.dart';
import '../profile/profile.dart';
import '../rundetails/RecentRunsScreen.dart';
import '../rundetails/RecordRunsScreen.dart';
import '../shared/UserSession.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? name;
  String? email;
  String? profileImageUrl;
  String _currentActivity = "Unknown"; // Holds the current detected activity
  StreamSubscription<Activity>? _activitySubscription;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data when HomeScreen initializes
    _initializeActivityRecognition();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel(); // Cancel subscription when disposing
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await UserSession().getUserData();
    setState(() {
      name = userData['name'];
      email = userData['email'];
      profileImageUrl = userData['profileImageUrl'];
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Initialize the activity recognition with additional debug output
  Future<void> _initializeActivityRecognition() async {
    final hasPermission = await _checkAndRequestPermission();
    print('Permission granted: $hasPermission');

    if (hasPermission) {
      _activitySubscription = FlutterActivityRecognition.instance.activityStream.listen(
            (activity) {
          print('Activity type: ${activity.type}');
          print('Activity confidence: ${activity.confidence}'); // Print confidence level

          setState(() {
            _currentActivity = '${activity.type.toString().split('.').last} (${activity.confidence}%)';
          });

          // Reset fallback timer whenever an activity is detected
          _fallbackTimer?.cancel();
          _fallbackTimer = Timer(Duration(seconds: 10), () {
            setState(() {
              _currentActivity = "Stationary"; // Fallback if no activity is detected
            });
          });
        },
        onError: (error) {
          print("Activity recognition error: $error");
          setState(() {
            _currentActivity = "Error";
          });
        },
      );
    } else {
      setState(() {
        _currentActivity = "Permission Denied";
      });
    }
  }

  // Request permission for activity recognition with fallback debug output
  Future<bool> _checkAndRequestPermission() async {
    ActivityPermission permission = await FlutterActivityRecognition.instance.checkPermission();
    if (permission == ActivityPermission.PERMANENTLY_DENIED) {
      print("Activity recognition permission permanently denied.");
      return false;
    } else if (permission == ActivityPermission.DENIED) {
      permission = await FlutterActivityRecognition.instance.requestPermission();
      if (permission != ActivityPermission.GRANTED) {
        print("Activity recognition permission denied.");
        return false;
      }
    }
    print("Activity recognition permission granted.");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Only create _pages once user data is loaded
    final List<Widget> _pages = [
      RecentRunsScreen(),
      RecordRunScreen(),
      StatsScreen(),
      ProfileScreen(name: name, email: email, profileImageUrl: profileImageUrl),
    ];

    // Titles for each screen
    final List<String> _titles = [
      'Home',
      'Record Run',
      'Statistics',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove the back arrow
        title: Text(_titles[_selectedIndex]), // Dynamically change title
      ),
      body: name == null || email == null || profileImageUrl == null
          ? const Center(child: CircularProgressIndicator()) // Show a loader while data is loading
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Current Activity: $_currentActivity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _pages[_selectedIndex]), // Display selected page content
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.run_circle),
            label: 'Record Run',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.blue, // Set to preferred background color
        selectedItemColor: Colors.white, // White for selected icon
        unselectedItemColor: Colors.white70, // White with slight opacity for unselected icons
      ),
    );
  }
}
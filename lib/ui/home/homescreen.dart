import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p2prunningapp/ui/rundetails/GPSRunScreen.dart';
import '../../services/ActivityRecognitionService.dart';
import '../profile/StatsScreen.dart';
import '../profile/profile.dart';
import '../rundetails/RecentRunsScreen.dart';
import '../rundetails/BleScanConnectionScreen.dart';
import '../shared/UserSession.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ActivityRecognitionService _activityService;
  String? name;
  String? email;
  String? profileImageUrl;
  String _currentActivity = "Unknown";
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _activityService = ActivityRecognitionService();
    _activityService.initialize();

    // Listen to shared activity updates
    _activityService.activityStream.listen((activity) {
      setState(() {
        _currentActivity = activity.type.toString().split('.').last;
      });
    });

    _loadUserData();
  }

  @override
  void dispose() {
    _activityService.dispose(); // Dispose shared service when HomeScreen is closed
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await UserSession().getUserData();
    //print('Loaded user data: $userData'); // Debug log

    setState(() {
      name = userData['username']; // Ensure this matches your saved key
      email = userData['email'];
      profileImageUrl = userData['profileImageUrl'];
    });

    // Check for null values
    if (name == null || email == null || profileImageUrl == null) {
      //print('Error: One or more user data fields are null!');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      RecentRunsScreen(),
      GPSRunScreen(),
      StatsScreen(),
      ProfileScreen(username: name, email: email, profileImageUrl: profileImageUrl),
    ];

    final List<String> _titles = [
      'Home',
      'Record Run',
      'Statistics',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_titles[_selectedIndex]),
      ),
        body: name == null
            ? const Center(child: CircularProgressIndicator())
          : _pages[_selectedIndex], // Updated to remove Current Activity bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.run_circle), label: 'Record Run'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
      ),
    );
  }
}
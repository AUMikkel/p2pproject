import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../profile/StatsScreen.dart';
import '../profile/profile.dart';
import '../rundetails/RecentRunsScreen.dart';
import '../rundetails/RecordRunsScreen.dart';
import '../shared/UserSession.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? name;
  String? email;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data when HomeScreen initializes
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
          : _pages[_selectedIndex],
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
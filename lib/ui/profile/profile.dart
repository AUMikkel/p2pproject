import 'package:flutter/material.dart';
import '../login/login.dart';
import '../rundetails/RunDetailsScreen.dart';
import '../shared/UserSession.dart'; // Import UserSession for managing session data

class ProfileScreen extends StatelessWidget {
  final String? username;
  final String? email;
  final String? profileImageUrl;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.email,
    required this.profileImageUrl,
  });

  void _navigateToRunDetails(BuildContext context, String runDetails) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RunDetailsScreen(runDetails: runDetails),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Clear user session data
    await UserSession().logout();

    // Navigate to the LoginScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: username ?? 'Not provided',
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: email ?? 'Not provided',
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
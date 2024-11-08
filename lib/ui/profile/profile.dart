import 'package:flutter/material.dart';
import '../login/login.dart';
import '../rundetails/RunDetailsScreen.dart';

class ProfileScreen extends StatelessWidget {
  final String? name;
  final String? email;
  final String? profileImageUrl;

  const ProfileScreen({
    super.key,
    required this.name,
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

  void _logout(BuildContext context) {
    // Implement logout logic here, e.g., clear user session or navigate to login screen.
    // Here we’ll just pop back to the main screen for illustration.

    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Add this to make content scrollable
          child: Column(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(profileImageUrl!),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    initialValue: email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Recent Runs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        ElevatedButton(
                          onPressed: () => _navigateToRunDetails(context, 'Run 1: 5 km in 25 min'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Run 1: 5 km in 25 min'),
                              Icon(Icons.terrain), // Mountain icon
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _navigateToRunDetails(context, 'Run 2: 10 km in 50 min'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Run 2: 10 km in 50 min'),
                              Icon(Icons.location_city), // Road icon
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _navigateToRunDetails(context, 'Run 3: 7 km in 35 min'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Run 3: 7 km in 35 min'),
                              Icon(Icons.forest), // Forest icon
                            ],
                          ),
                        ),
                      ],
                    ),
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
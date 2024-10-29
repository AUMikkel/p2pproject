import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p2prunningapp/ui/profile/profile.dart';
import 'package:p2prunningapp/ui/register/register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    if (_formKey.currentState!.validate()) {
      // Perform login action
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ProfileScreen(
            name: 'User', // Replace with actual user name if available
            email: _emailController.text,
            profileImageUrl: 'https://example.com/profile.jpg', // Placeholder image URL
          ),
        ),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const RegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            // Position the large logo towards the top without affecting the form
            const Positioned(
              top: 60, // Adjust this value to control the height of the logo
              left: 0,
              right: 0,
              child: CircleAvatar(
                radius: 150, // Make the logo larger
                backgroundImage: AssetImage('lib/assets/p2plogo.jpg'),
                backgroundColor: Colors.transparent,
              ),
            ),
            // Center the form content vertically without moving the form down too much
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 300), // Push form below the large logo
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _login,
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _navigateToRegister,
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
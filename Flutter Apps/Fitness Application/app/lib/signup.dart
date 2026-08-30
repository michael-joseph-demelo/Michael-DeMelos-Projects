import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _reEnterPasswordController = TextEditingController();

  String? _validatePassword() {
    if (_passwordController.text != _reEnterPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signUp() async {
    // Check if an account with the provided email already exists
    QuerySnapshot<Map<String, dynamic>> existingUser = await _firestore
        .collection('signup')
        .where('email', isEqualTo: _emailController.text.trim())
        .get();

    if (existingUser.docs.isNotEmpty) {
      // An account with the provided email already exists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An account with this email already exists'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Continue with the sign-up process if the email is unique
    if (_validatePassword() != null) {
      // Passwords do not match
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Store user data in Firestore (Note: Password is stored in plaintext for educational purposes)
      await _firestore.collection('signup').add({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text, // Storing password in plaintext for educational purposes
        // Add more fields as needed
      });

      // Show a snackbar for successful sign-up
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully signed up!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );

      // You may navigate to another page or perform any other action after successful sign-up
    } catch (e) {
      // Handle errors
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@example.com', // Placeholder text
                ),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _reEnterPasswordController,
                decoration: InputDecoration(labelText: 'Re-enter Password'),
                obscureText: true,
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.lightBlue[200],
    );
  }
}

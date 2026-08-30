// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'welcome.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sleep_tracker_provider.dart';

//main function
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp( options: DefaultFirebaseOptions.currentPlatform, );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepTrackerProvider()),
        // Add other providers if needed
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomePage(),
    );
  }
}
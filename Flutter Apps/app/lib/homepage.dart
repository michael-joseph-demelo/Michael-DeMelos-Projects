import 'package:app/welcome.dart';
import 'package:flutter/material.dart';
import 'checklist_page.dart';
import 'goals_page.dart';
import 'mood_page.dart';
import 'sleep_page.dart';
import 'mindful_page.dart';
import 'travel_page.dart';
import 'music_page.dart';
import 'memory_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HOMEPAGE'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _scheduleDailyNotification();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleDailyNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Mindfulness Reminder',
      'Take your daily mindfulness break!',
      _dailyNotificationTime(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindfulness_page',
          'Mindfulness Page',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _dailyNotificationTime() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18,
      0,
    );
    return scheduledDate;
  }

  final List<IconData> icons = [
    Icons.checklist_rounded,
    Icons.alt_route_rounded,
    Icons.face,
    Icons.airline_seat_individual_suite,
    Icons.spa,
    Icons.airplane_ticket_rounded,
    Icons.music_note,
    Icons.camera_alt,
  ];

  final List<String> iconLabels = [
    'Daily Checklist',
    'Goals',
    'Mood Tracker',
    'Sleep Tracker',
    'Mindful Breaks',
    'Travel',
    'Music',
    'Memory',
  ];

  void navigateToPage(IconData icon) {
    Widget destinationPage;

    switch (icon) {
      case Icons.checklist_rounded:
        destinationPage = ChecklistPage();
        break;
      case Icons.alt_route_rounded:
        destinationPage = GoalsPage();
        break;
      case Icons.face:
        destinationPage = MoodPage();
        break;
      case Icons.airline_seat_individual_suite:
        destinationPage = SleepTrackerScreen();
        break;
      case Icons.spa:
        destinationPage = MindfulPage();
        break;
      case Icons.airplane_ticket_rounded:
        destinationPage = TravelPage();
        break;
      case Icons.music_note:
        destinationPage = MusicPage();
        break;
      case Icons.camera_alt:
        destinationPage = MemoryPage();
        break;

      default:
        destinationPage = ChecklistPage(); // A placeholder page for icons without a defined destination
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return destinationPage; // Navigate to the appropriate page
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold,),),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.logout),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => WelcomePage(),
              ),
            );
          },
        ),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              navigateToPage(icons[index]);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icons[index],
                  size: 110,
                ),
                Text(
                  iconLabels[index],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: Colors.lightBlue[200],
    );
  }
}
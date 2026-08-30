import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class MindfulPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mindfulness App',
      home: MindfulnessPage(),
    );
  }
}

class MindfulnessPage extends StatefulWidget {
  @override
  _MindfulnessPageState createState() => _MindfulnessPageState();
}

class _MindfulnessPageState extends State<MindfulnessPage> {
  late Timer _breathingTimer;
  late Timer _reflectionTimer;

  double _breathingProgress = 0.0;
  double _reflectionProgress = 0.0;

  int _breathingTimeLeft = 5 * 60; // 5 minutes in seconds
  int _reflectionTimeLeft = 10 * 60; // 10 minutes in seconds

  bool _breathingTimerRunning = false;
  bool _reflectionTimerRunning = false;

  int _totalMindfulnessMinutes = 0;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _loadMindfulnessStats();
    _updateTotalMindfulnessMinutes();
    _initializeNotifications();
    _scheduleDailyNotification();
  }

  @override
  void dispose() {
    _saveMindfulnessStats();
    _breathingTimer.cancel();
    _reflectionTimer.cancel();
    _flutterLocalNotificationsPlugin.cancelAll();
    super.dispose();
  }

  void _initializeNotifications() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleDailyNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Mindfulness Reminder',
      'Take your daily mindfulness break!',
      _dailyNotificationTime(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mindfulness_channel',
          'Mindfulness Channel',
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
    final tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 0);
    return scheduledDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mindfulness',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.lightBlueAccent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.home,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MyApp()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mindfulness Stats (Past Week)',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Total Mindfulness Minutes: $_totalMindfulnessMinutes',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _buildExerciseContainer(
              'Breathing Exercise',
              _breathingProgress,
              _breathingTimeLeft,
              _breathingTimerRunning,
                  () => _toggleBreathingTimer(),
            ),
            SizedBox(height: 20),
            _buildExerciseContainer(
              'Reflection Exercise',
              _reflectionProgress,
              _reflectionTimeLeft,
              _reflectionTimerRunning,
                  () => _toggleReflectionTimer(),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.lightBlue[200],
    );
  }

  Widget _buildExerciseContainer(
      String title,
      double progress,
      int timeLeft,
      bool timerRunning,
      VoidCallback onPressed,
      ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          SizedBox(height: 10),
          CircularPercentIndicator(
            radius: 120.0,
            lineWidth: 10.0,
            percent: progress,
            center: Text(formatDuration(Duration(seconds: timeLeft))),
            progressColor: Colors.white,
            backgroundColor: Colors.transparent,
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(timerRunning ? 'Stop' : 'Start $title'),
          ),
        ],
      ),
    );
  }

  void _toggleBreathingTimer() {
    setState(() {
      _breathingTimerRunning = !_breathingTimerRunning;
    });

    if (_breathingTimerRunning) {
      _startBreathingTimer();
    } else {
      _pauseBreathingTimer();
    }
  }

  void _startBreathingTimer() {
    _breathingProgress = 0.0;
    setState(() {});

    _breathingTimer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_breathingTimeLeft <= 0) {
        _breathingTimer.cancel();
        _onTimerComplete('Breathing Exercise');
      } else {
        setState(() {
          _breathingTimeLeft--;
          _breathingProgress += 1 / (5 * 60);
        });
        _updateTotalMindfulnessMinutes();
      }
    });
  }

  void _pauseBreathingTimer() {
    _breathingTimer.cancel();
  }

  void _toggleReflectionTimer() {
    setState(() {
      _reflectionTimerRunning = !_reflectionTimerRunning;
    });

    if (_reflectionTimerRunning) {
      _startReflectionTimer();
    } else {
      _pauseReflectionTimer();
    }
  }

  void _startReflectionTimer() {
    _reflectionProgress = 0.0;
    setState(() {});

    _reflectionTimer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_reflectionTimeLeft <= 0) {
        _reflectionTimer.cancel();
        _onTimerComplete('Reflection Exercise');
      } else {
        setState(() {
          _reflectionTimeLeft--;
          _reflectionProgress += 1 / (10 * 60);
        });
        _updateTotalMindfulnessMinutes();
      }
    });
  }

  void _pauseReflectionTimer() {
    _reflectionTimer.cancel();
  }

  void _onTimerComplete(String exerciseType) {
    showMindfulnessNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Completed $exerciseType'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void showMindfulnessNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'mindfulness_channel',
      'Mindfulness Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Mindfulness Reminder',
      'Take a mindful break!',
      platformChannelSpecifics,
      payload: 'mindfulness_payload',
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  void _updateTotalMindfulnessMinutes() {
    int breathingMinutes = 5 -
        ((_breathingTimeLeft / 60) - (_breathingProgress * 5)).floor();
    int reflectionMinutes = 10 -
        ((_reflectionTimeLeft / 60) - (_reflectionProgress * 10)).floor();
    _totalMindfulnessMinutes = breathingMinutes + reflectionMinutes;
  }

  void _loadMindfulnessStats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalMindfulnessMinutes = prefs.getInt('totalMindfulnessMinutes') ?? 0;
    });
  }

  void _saveMindfulnessStats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('totalMindfulnessMinutes', _totalMindfulnessMinutes);
  }
}

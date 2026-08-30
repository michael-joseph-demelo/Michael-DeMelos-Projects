import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sleep_tracker_provider.dart';
import 'sleep_record.dart';
import 'homepage.dart';

class SleepInputForm extends StatefulWidget {
  @override
  _SleepInputFormState createState() => _SleepInputFormState();
}

class _SleepInputFormState extends State<SleepInputForm> {
  final TextEditingController sleepHoursController = TextEditingController();
  final TextEditingController sleepMinutesController = TextEditingController();
  final TextEditingController wakeUpHoursController = TextEditingController();
  final TextEditingController wakeUpMinutesController = TextEditingController();
  String sleepPeriod = 'AM';
  String wakeUpPeriod = 'AM';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Sleep Record',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sleepHoursController,
                    decoration: InputDecoration(labelText: 'Hour Slept At'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: sleepMinutesController,
                    decoration: InputDecoration(labelText: 'Minute Slept At'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                DropdownButton<String>(
                  value: sleepPeriod,
                  onChanged: (String? value) {
                    setState(() {
                      sleepPeriod = value!;
                    });
                  },
                  items: ['AM', 'PM'].map<DropdownMenuItem<String>>((
                      String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wakeUpHoursController,
                    decoration: InputDecoration(labelText: 'Hour Woke Up'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: wakeUpMinutesController,
                    decoration: InputDecoration(labelText: 'Minute Woke Up'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                DropdownButton<String>(
                  value: wakeUpPeriod,
                  onChanged: (String? value) {
                    setState(() {
                      wakeUpPeriod = value!;
                    });
                  },
                  items: ['AM', 'PM'].map<DropdownMenuItem<String>>((
                      String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _addSleepRecord(context);
              },
              child: Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSleepRecord(BuildContext context) {
    final sleepTrackerProvider = Provider.of<SleepTrackerProvider>(
        context, listen: false);

    int sleepHours = int.tryParse(sleepHoursController.text) ?? 0;
    int sleepMinutes = int.tryParse(sleepMinutesController.text) ?? 0;
    int wakeUpHours = int.tryParse(wakeUpHoursController.text) ?? 0;
    int wakeUpMinutes = int.tryParse(wakeUpMinutesController.text) ?? 0;

    if (sleepPeriod == 'PM' && sleepHours < 12) {
      sleepHours += 12;
    }

    if (wakeUpPeriod == 'PM' && wakeUpHours < 12) {
      wakeUpHours += 12;
    }

    DateTime now = DateTime.now();
    DateTime sleepTime = DateTime(
        now.year, now.month, now.day, sleepHours, sleepMinutes);
    DateTime wakeUpTime = DateTime(
        now.year, now.month, now.day, wakeUpHours, wakeUpMinutes);

    if (sleepTime.isAfter(wakeUpTime)) {
      sleepTime = sleepTime.subtract(Duration(days: 1));
    }

    SleepRecord newRecord = SleepRecord(
        sleepTime: sleepTime, wakeUpTime: wakeUpTime);

    sleepTrackerProvider.addSleepRecord(newRecord);

    // Show Snackbar with Undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Record added'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Handle Undo action (remove the record)
            sleepTrackerProvider.removeLastSleepRecord();
          },
        ),
      ),
    );

    // Clear text controllers
    sleepHoursController.clear();
    sleepMinutesController.clear();
    wakeUpHoursController.clear();
    wakeUpMinutesController.clear();
  }
}

class SleepTrackerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sleep Tracker', style: TextStyle(fontWeight: FontWeight.bold,),),
        centerTitle: true,
        backgroundColor: Colors.lightBlueAccent,
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
      backgroundColor: Colors.lightBlue[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SleepInputForm(),
            SizedBox(height: 20),
            WeeklyAverageDisplay(),
          ],
        ),
      ),
    );
  }
}

class WeeklyAverageDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sleepTrackerProvider = Provider.of<SleepTrackerProvider>(context);

    String weeklyAverage = sleepTrackerProvider.calculateWeeklyAverage();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Sleep Average',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Average Sleep Duration: $weeklyAverage',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
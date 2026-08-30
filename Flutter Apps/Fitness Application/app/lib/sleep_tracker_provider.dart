import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'sleep_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SleepTrackerProvider extends ChangeNotifier {
  List<SleepRecord> _sleepRecords = [];

  List<SleepRecord> get sleepRecords => _sleepRecords;

  Future<void> addSleepRecord(SleepRecord record) async {
    _sleepRecords.add(record);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> _saveToLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> sleepRecordsStringList = _sleepRecords.map((record) => record.toString()).toList();
    prefs.setStringList('sleepRecords', sleepRecordsStringList);
  }

  SleepTrackerProvider() {
    _loadFromLocalStorage();
  }

  Future<void> _loadFromLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? sleepRecordsStringList = prefs.getStringList('sleepRecords');
    if (sleepRecordsStringList != null) {
      _sleepRecords = sleepRecordsStringList.map((recordString) => SleepRecord.fromString(recordString)).toList();
      notifyListeners();
    }
  }

  String calculateWeeklyAverage() {
    if (_sleepRecords.isEmpty) {
      return '0h 0m'; // Return '0h 0m' if there are no sleep records
    }

    // Calculate the total duration and count of sleep records for the week
    Duration totalDuration = Duration();
    int recordCount = 0;

    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

    for (SleepRecord record in _sleepRecords) {
      if (record.sleepTime.isAfter(startOfWeek) && record.sleepTime.isBefore(endOfWeek)) {
        DateTime adjustedWakeUpTime = record.wakeUpTime.isBefore(record.sleepTime)
            ? record.wakeUpTime.add(Duration(days: 1))
            : record.wakeUpTime;

        // Adjust sleep time to be the same day as wake-up time if it's midnight
        DateTime adjustedSleepTime =
        record.sleepTime.hour == 0 ? record.sleepTime.add(Duration(days: 1)) : record.sleepTime;

        totalDuration += adjustedWakeUpTime.isBefore(adjustedSleepTime)
            ? Duration() // Ignore invalid records where wake-up time is before adjusted sleep time
            : adjustedWakeUpTime.difference(adjustedSleepTime);

        recordCount++;
      }
    }

    // Calculate the average duration
    Duration averageDuration = recordCount > 0 ? totalDuration ~/ recordCount : Duration();

    // Format the result as 'Xh Ym'
    String formattedResult = '${averageDuration.inHours}h ${averageDuration.inMinutes % 60}m';

    return formattedResult;
  }

  void removeLastSleepRecord() {
    if (_sleepRecords.isNotEmpty) {
      _sleepRecords.removeLast();
      notifyListeners();
    }
  }
}
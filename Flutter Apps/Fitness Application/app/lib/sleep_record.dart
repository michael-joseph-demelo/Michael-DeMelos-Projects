class SleepRecord {
  final DateTime sleepTime;
  final DateTime wakeUpTime;

  SleepRecord({required this.sleepTime, required this.wakeUpTime});

  factory SleepRecord.fromString(String recordString) {
    List<String> parts = recordString.split(',');

    DateTime sleepTime = DateTime.parse(parts[0]);
    DateTime wakeUpTime = DateTime.parse(parts[1]);

    return SleepRecord(sleepTime: sleepTime, wakeUpTime: wakeUpTime);
  }

  @override
  String toString() {
    return 'SleepRecord{sleepTime: ${sleepTime.toIso8601String()}, wakeUpTime: ${wakeUpTime.toIso8601String()}';
  }

}
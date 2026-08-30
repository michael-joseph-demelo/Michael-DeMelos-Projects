import 'package:flutter/material.dart';
import 'homepage.dart';
class MoodPage extends StatefulWidget {
  @override
  _MoodPageState createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  List<String> moodSelections = List.filled(7, '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mood Tracker', style: TextStyle(fontWeight: FontWeight.bold,),),
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Reset mood selections for each day
              setState(() {
                moodSelections = List.filled(7, '');
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              // Navigate to the history page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryPage(moodSelections)),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.lightBlue[200],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 0,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[0] = mood;
                    });
                  },
                ),
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 1,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[1] = mood;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            // Second Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 2,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[2] = mood;
                    });
                  },
                ),
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 3,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[3] = mood;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            // Third Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 4,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[4] = mood;
                    });
                  },
                ),
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 5,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[5] = mood;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            // Fourth Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MoodButton(
                  moodIcon: Icons.sentiment_very_satisfied,
                  day: 6,
                  onMoodSelected: (mood) {
                    setState(() {
                      moodSelections[6] = mood;
                    });
                  },
                ),
                // Adjust the spacing or add more MoodButtons if needed
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MoodButton extends StatelessWidget {
  final IconData moodIcon;
  final int day;
  final ValueChanged<String> onMoodSelected;

  MoodButton({
    required this.moodIcon,
    required this.day,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Expanded(
      child: InkWell(
        onTap: () {
          _showMoodSelectionDialog(context, dayNames[day]);
        },
        child: Container(
          padding: EdgeInsets.all(15),
          margin: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Column(
            children: [
              Icon(
                moodIcon,
                size: 40,
              ),
              SizedBox(height: 10),
              Text(
                dayNames[day],
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoodSelectionDialog(BuildContext context, String dayName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final List<MoodData> moodDataList = [
          MoodData(name: 'Very Satisfied', icon: Icons.sentiment_very_satisfied),
          MoodData(name: 'Satisfied', icon: Icons.sentiment_satisfied),
          MoodData(name: 'Neutral', icon: Icons.sentiment_neutral),
          MoodData(name: 'Dissatisfied', icon: Icons.sentiment_dissatisfied),
          MoodData(name: 'Very Dissatisfied', icon: Icons.sentiment_very_dissatisfied),
        ];

        return AlertDialog(
          title: Text('Select Mood for $dayName'),
          content: Column(
            children: [
              ...moodDataList.map((data) => buildMoodButton(context, data)).toList(),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Back'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildMoodButton(BuildContext context, MoodData moodData) {
    return InkWell(
      onTap: () {
        onMoodSelected(moodData.name);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: EdgeInsets.all(15),
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          moodData.icon,
          size: 50,
        ),
      ),
    );
  }
}

class MoodData {
  final String name;
  final IconData icon;

  MoodData({required this.name, required this.icon});
}

class HistoryPage extends StatefulWidget {
  final List<String> moodSelections;

  HistoryPage(this.moodSelections);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Define a mapping between mood names and their corresponding icons
  final Map<String, IconData> moodNameToIcon = {
    'Very Satisfied': Icons.sentiment_very_satisfied,
    'Satisfied': Icons.sentiment_satisfied,
    'Neutral': Icons.sentiment_neutral,
    'Dissatisfied': Icons.sentiment_dissatisfied,
    'Very Dissatisfied': Icons.sentiment_very_dissatisfied,
  };

  final List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History Page'),
      ),
      body: ListView.builder(
        itemCount: widget.moodSelections.length,
        itemBuilder: (context, index) {
          // Get the mood icon from the mapping
          IconData moodIcon = moodNameToIcon[widget.moodSelections[index]] ?? Icons.error;
          return ListTile(
            title: Text('${dayNames[index]}: ${widget.moodSelections[index]}'),
            leading: Icon(moodIcon),
          );
        },
      ),
    );
  }
}



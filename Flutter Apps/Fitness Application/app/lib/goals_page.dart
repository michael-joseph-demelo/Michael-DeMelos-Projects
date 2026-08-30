import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class GoalItem {
  final TextEditingController textController;
  DateTime goalDate;
  double goalCompletion;
  bool isTextEditable;

  GoalItem({
    required this.textController,
    required this.goalDate,
    required this.goalCompletion,
    this.isTextEditable = true,
  });
}

class GoalsPage extends StatefulWidget {
  @override
  _GoalsPageState createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<GoalItem> goals = [];
  bool isTextEditable = true;


  @override
  void initState() {
    super.initState();
    _loadGoals();
  }


  void _saveGoals() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> goalsStringList = goals.map((goal) => goal.textController.text).toList();
    prefs.setStringList('goals', goalsStringList);
  }


  void _loadGoals() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? goalsStringList = prefs.getStringList('goals');

    if (goalsStringList != null) {
      setState(() {
        goals = goalsStringList
            .map((goalText) => GoalItem(
          textController: TextEditingController(text: goalText),
          goalDate: DateTime.now().add(Duration(days: 30)),
          goalCompletion: 0.0,
        ))
            .toList();
      });
    }
  }

  void _addNewGoal() {
    TextEditingController textController = TextEditingController(text: '');
    DateTime goalDate = DateTime.now().add(Duration(days: 30));
    double goalCompletion = 0.0;

    setState(() {
      goals.add(GoalItem(
        textController: textController,
        goalDate: goalDate,
        goalCompletion: goalCompletion,
      ));
    });

    _saveGoals();
  }

  void _selectDate(BuildContext context, GoalItem goal) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: goal.goalDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != goal.goalDate) {
      setState(() {
        goal.goalDate = picked;
      });
    }
  }

  Future _trackDaysLeft(BuildContext context, GoalItem goal) async {
    final now = DateTime.now();
    final difference = goal.goalDate.difference(now).inDays;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text('$difference days left to reach your goal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPositiveMessage(double completion) {
    String message = '';

    if ((completion * 100).toInt() == 25) {
      message = "Well done! You're making progress and keep up the good work.";
    } else if ((completion * 100).toInt() == 50) {
      message = "Amazing Work! You're halfway done in accomplishing your goal.";
    } else if ((completion * 100).toInt() == 75) {
      message = "Excellent Work! You completed 75% of your goal and only have 25% left. You can do it!";
    } else if ((completion * 100).toInt() == 100) {
      message = "Congratulations for finally completing your goal";
    }

    if (message.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void deleteItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text('Are you sure you want to delete this goal?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'NO'),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  goals.removeAt(index);
                });
                Navigator.pop(context, 'YES');
              },
              child: const Text('YES'),
            ),
          ],
        );
      },
    );

    _saveGoals();
  }

  void editItemGoals(int index) {
    TextEditingController editController =
    TextEditingController(text: goals[index].textController.text);
    isTextEditable = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Goal"),
          content: TextField(
            controller: editController,
            enabled: isTextEditable,
            decoration: InputDecoration(labelText: 'Edit your goal'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'Cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  goals[index] = GoalItem(
                    textController: editController,
                    goalDate: goals[index].goalDate,
                    goalCompletion: goals[index].goalCompletion,
                    isTextEditable: false, // Set isTextEditable to false
                  );
                });
                Navigator.pop(context, 'OK');
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    _saveGoals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Goals Tracker', style: TextStyle(fontWeight: FontWeight.bold,),),
        backgroundColor: Colors.lightBlueAccent,
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: goals.length,
        itemBuilder: (context, index) {
          GoalItem goal = goals[index];
          return ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: goal.textController,
                        decoration: InputDecoration(labelText: 'Enter your goal'),
                        enabled: goal.isTextEditable,
                        onChanged: (value) {
                          setState(() {
                            goal.isTextEditable = true;
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            goal.isTextEditable = false;
                          });
                        },
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.access_time),
                          onPressed: () => _trackDaysLeft(context, goal),
                        ),
                        IconButton(
                          icon: Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context, goal),
                        ),
                        PopupMenuButton(
                          onSelected: (String value) {
                            if (value == 'edit') {
                              editItemGoals(index);
                            } else if (value == 'delete') {
                              deleteItem(index);
                            }
                          },
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('${(goal.goalCompletion * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: goal.goalCompletion,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: (value) {
                          setState(() {
                            goal.goalCompletion = value;
                          });

                          _showPositiveMessage(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addNewGoal();
        },
        child: Icon(Icons.add),
      ),
      backgroundColor: Colors.lightBlue[200],
    );
  }
}

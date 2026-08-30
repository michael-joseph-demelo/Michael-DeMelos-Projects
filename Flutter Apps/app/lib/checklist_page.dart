import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ChecklistItem {
  final String text;
  bool isChecked;
  bool isStarHighlighted;
  bool isEditHighlighted;
  bool isTextEditable_Checklist;

  ChecklistItem({
    required this.text,
    required this.isChecked,
    this.isTextEditable_Checklist = true,
  })   : isStarHighlighted = false,
        isEditHighlighted = false;
}

class ChecklistPage extends StatefulWidget {
  @override
  _ChecklistPageState createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  List<ChecklistItem> items = [];
  bool isTextEditable_Checklist = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? itemsStringList = prefs.getStringList('checklist_items');

    if (itemsStringList != null) {
      setState(() {
        items = itemsStringList
            .map((itemText) => ChecklistItem(
          text: itemText,
          isChecked: false,
        ))
            .toList();
      });
    }
  }

  void _saveItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> itemsStringList = items.map((item) => item.text).toList();
    prefs.setStringList('checklist_items', itemsStringList);
  }

  void _addNewItem() {
    setState(() {
      items.add(ChecklistItem(text: '', isChecked: false));
      _saveItems();
    });
  }

  void toggleStarHighlight(int index) {
    setState(() {
      items[index].isStarHighlighted = !items[index].isStarHighlighted;
    });
  }

  void toggleEditHighlight(int index) {
    setState(() {
      items[index].isEditHighlighted = !items[index].isEditHighlighted;
    });
  }

  void deleteItemChecklist(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text('Are you sure you want to delete this item from the checklist?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'NO');
              },
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  items.removeAt(index);
                });
                _saveItems();
                Navigator.pop(context, 'YES');
              },
              child: const Text('YES'),
            ),
          ],
        );
      },
    );
  }

  void editItemCheckList(int index) {
    TextEditingController editController = TextEditingController(text: items[index].text);
    bool isTextEditable_Checklist = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit"),
          content: TextField(
            controller: editController,
            enabled: isTextEditable_Checklist,
            decoration: InputDecoration(labelText: 'Edit your checklist item'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'Cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  items[index] = ChecklistItem(
                    text: editController.text,
                    isChecked: items[index].isChecked,
                    isTextEditable_Checklist: false,
                  );
                });
                _saveItems();
                Navigator.pop(context, 'OK');
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Daily Checklist', style: TextStyle(fontWeight: FontWeight.bold,),),
        backgroundColor: Colors.lightBlueAccent,
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Checkbox(
              value: items[index].isChecked,
              onChanged: (bool? value) {
                setState(() {
                  items[index].isChecked = value!;
                });
                _saveItems();
              },
            ),
            title: TextField(
              controller: TextEditingController(text: items[index].text),
              readOnly: !items[index].isTextEditable_Checklist,
              onSubmitted: (String value) {
                setState(() {
                  items[index] = ChecklistItem(
                    text: value,
                    isChecked: items[index].isChecked,
                    isTextEditable_Checklist: false,
                  );
                });
                _saveItems();
              },
              decoration: InputDecoration(
                labelText: '',
                fillColor: items[index].isEditHighlighted ? Colors.yellow : Colors.transparent,
                filled: items[index].isEditHighlighted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    toggleStarHighlight(index);
                  },
                  icon: Icon(
                    Icons.star,
                    color: items[index].isStarHighlighted ? Colors.blue : Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    toggleEditHighlight(index);
                  },
                  icon: Icon(
                    Icons.edit,
                    color: items[index].isEditHighlighted ? Colors.blue : Colors.grey,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'edit') {
                      editItemCheckList(index);
                    } else if (value == 'delete') {
                      deleteItemChecklist(index);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _addNewItem();
        },
        child: Icon(Icons.add),
      ),

      backgroundColor: Colors.lightBlue[200],
    );
  }
}

import 'package:flutter/material.dart';
import 'http_service.dart';
import 'country.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TravelPage extends StatefulWidget {
  @override
  _TravelPageState createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  final AppState appState = AppState();
  final TextEditingController row1Controller = TextEditingController();
  final TextEditingController row2Controller = TextEditingController();
  List<String> itemsForRow1 = [];
  List<String> itemsForRow2 = [];
  bool showRecommendations = true;
  final HttpService httpService = HttpService();

  @override
  Widget build(BuildContext context) {
    itemsForRow1 = appState.itemsForRow1;
    itemsForRow2 = appState.itemsForRow2;
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel', style: TextStyle(fontWeight: FontWeight.bold,),),
        backgroundColor: Colors.lightBlueAccent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: () {
            appState.itemsForRow1 = itemsForRow1;
            appState.itemsForRow2 = itemsForRow2;
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (showRecommendations)
                ElevatedButton(
                  onPressed: () {
                    // Set showRecommendations to false to hide the button.
                    setState(() {
                      showRecommendations = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.lightBlueAccent,
                  ),
                  child: Text('Click For Recommendations'),
                ),
              if (!showRecommendations)
                Container(
                  color: Colors.white.withOpacity(0.3),
                  height: 200,
                  child: FutureBuilder<List<Country>>(
                    future: httpService.getRecommendations(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (snapshot.hasData) {
                        final countries = snapshot.data;
                        return ListView.builder(
                          itemCount: countries?.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: SvgPicture.network(
                                countries![index].flag!,
                                width: 50, // Adjust width as needed
                                height: 50, // Adjust height as needed
                              ),
                              title: Text(countries[index].name!),
                            );
                          },
                        );
                      } else {
                        return Center(child: Text('No recommendations available.'));
                      }
                    },
                  ),
                ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: buildRowWithList(itemsForRow1, row1Controller, 'Add Places To Visit'),
                  ),
                  SizedBox(width: 20), // Adjust the width as needed
                  Expanded(
                    child: buildRowWithList(itemsForRow2, row2Controller, 'Add Visited Places'),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.lightBlue[200],
    );
  }

  Widget buildRowWithList(
      List<String> items, TextEditingController controller, String labelText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (text) {
                  setState(() {
                    items.add(text);
                    controller.clear();
                  });
                },
                decoration: InputDecoration(
                  labelText: labelText,
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: Colors.lightBlueAccent,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final itemText = entry.value;
              return ListTile(
                title: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade400),
                    Expanded(child: Text(itemText)),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade600),
                      onPressed: () {
                        setState(() {
                          items.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    row1Controller.dispose();
    row2Controller.dispose();
    super.dispose();
  }
}

class AppState {
  static final AppState instance = AppState.internal();

  factory AppState() {
    return instance;
  }

  AppState.internal();
  List<String> itemsForRow1 = [];
  List<String> itemsForRow2 = [];
}
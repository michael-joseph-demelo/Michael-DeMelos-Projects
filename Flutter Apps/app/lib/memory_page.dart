import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'homepage.dart';

class MemoryPage extends StatefulWidget {
  @override
  _MemoryPageState createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Memory', style: TextStyle(fontWeight: FontWeight.bold,),),
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
      backgroundColor: Colors.lightBlue[200],
      body: Column(
        children: [
          TableCalendar(
            calendarFormat: _calendarFormat,
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2050),
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhotoGalleryPage(selectedDay: _selectedDay),
                ),
              );
            },
            child: Text('Open Photo Journal'),
          ),
        ],
      ),
    );
  }
}

class PhotoGalleryPage extends StatefulWidget {
  final DateTime? selectedDay;

  PhotoGalleryPage({required this.selectedDay});

  @override
  _PhotoGalleryPageState createState() => _PhotoGalleryPageState();
}

enum PhotoView {
  Normal,
  Grid,
  Slideshow,
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late List<File> _selectedPhotos;
  late List<bool> _isSelectedList;
  bool _isSelectionMode = false;
  PhotoView _currentPhotoView = PhotoView.Normal;

  @override
  void initState() {
    super.initState();
    _selectedPhotos = [];
    _isSelectedList = []; // Initialize an empty list
    _loadPhotosForSelectedDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Gallery'),
        leading: _isSelectionMode
            ? IconButton(
          icon: Icon(Icons.cancel),
          onPressed: () {
            _exitSelectionMode();
          },
        )
            : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _savePhotosForSelectedDay();
            Navigator.pop(context);
          },
        ),
        actions: _isSelectionMode
            ? [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              _confirmDelete();
            },
          ),
        ]
            : [
          if (_currentPhotoView != PhotoView.Slideshow)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                _enterSelectionMode();
              },
            ),
          PopupMenuButton<PhotoView>(
            onSelected: (view) {
              _changePhotoView(view);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<PhotoView>(
                value: PhotoView.Normal,
                child: Text('Normal View'),
              ),
              PopupMenuItem<PhotoView>(
                value: PhotoView.Grid,
                child: Text('Grid View'),
              ),
              PopupMenuItem<PhotoView>(
                value: PhotoView.Slideshow,
                child: Text('Slideshow View'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Photos for ${_formattedSelectedDay()}'),
            SizedBox(height: 16),
            _buildPhotoView(),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
        onPressed: () {
          _addPhotoFromGallery();
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildPhotoView() {
    switch (_currentPhotoView) {
      case PhotoView.Normal:
        return _buildNormalPhotoView();
      case PhotoView.Grid:
        return _buildGridPhotoView();
      case PhotoView.Slideshow:
        return _buildSlideshowPhotoView();
    }
  }

  Widget _buildNormalPhotoView() {
    return Expanded(
      child: ListView.builder(
        itemCount: _selectedPhotos.length,
        itemBuilder: (context, index) {
          return _buildPhotoItem(index);
        },
      ),
    );
  }

  Widget _buildGridPhotoView() {
    return Expanded(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // You can adjust the number of columns as needed
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _selectedPhotos.length,
        itemBuilder: (context, index) {
          return _buildPhotoItem(index);
        },
      ),
    );
  }

  Widget _buildSlideshowPhotoView() {
    return AspectRatio(
      aspectRatio: 16 / 9, // Set a default aspect ratio
      child: CarouselSlider(
        options: CarouselOptions(
          height: double.infinity, // Use the available height
          autoPlay: true,
          autoPlayInterval: Duration(seconds: 3),
          autoPlayAnimationDuration: Duration(milliseconds: 800),
          autoPlayCurve: Curves.fastOutSlowIn,
          pauseAutoPlayOnTouch: true,
          enlargeCenterPage: true,
        ),
        items: _selectedPhotos.map((photo) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                width: MediaQuery.of(context).size.width,
                margin: EdgeInsets.symmetric(horizontal: 5.0),
                child: Image.file(
                  photo,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  void _changePhotoView(PhotoView view) {
    setState(() {
      _currentPhotoView = view;
    });
  }

  Widget _buildPhotoItem(int index) {
    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
        _toggleSelection(index);
      }
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: _isSelectedList.length > index && _isSelectedList[index]
              ? Border.all(color: Colors.blue, width: 3.0) // Highlight selected photos
              : null,
        ),
        child: Image.file(
          _selectedPhotos[index],
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _clearSelection();
    });
  }

  void _confirmDelete() {
    _deleteSelectedPhotos();
    _exitSelectionMode();
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_isSelectedList.length <= index) {
        _isSelectedList.addAll(List.filled(index - _isSelectedList.length + 1, false));
      }
      _isSelectedList[index] = !_isSelectedList[index];
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectedList.clear();
    });
  }

  void _deleteSelectedPhotos() {
    setState(() {
      for (int i = _isSelectedList.length - 1; i >= 0; i--) {
        if (_isSelectedList[i]) {
          _selectedPhotos.removeAt(i);
          _isSelectedList.removeAt(i);
        }
      }
    });
  }

  String _formattedSelectedDay() {
    if (widget.selectedDay != null) {
      DateTime formattedDay =
      DateTime(widget.selectedDay!.year, widget.selectedDay!.month, widget.selectedDay!.day);
      return DateFormat('MMMM d, y').format(formattedDay.toLocal());
    } else {
      return 'No day selected';
    }
  }

  Future<void> _addPhotoFromGallery() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedPhotos.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // Handle errors, such as user canceling the image picking process.
      print('Error picking image: $e');
    }
  }

  Future<void> _loadPhotosForSelectedDay() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? photoPaths = prefs.getStringList(_getKeyForSelectedDay());
    if (photoPaths != null) {
      setState(() {
        _selectedPhotos = photoPaths.map((path) => File(path)).toList();
      });
    } else {
      _selectedPhotos = [];
    }
  }

  Future<void> _savePhotosForSelectedDay() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> photoPaths = _selectedPhotos.map((photo) => photo.path).toList();
    prefs.setStringList(_getKeyForSelectedDay(), photoPaths);
  }

  String _getKeyForSelectedDay() {
    return 'photos_${widget.selectedDay?.toString()}';
  }
}
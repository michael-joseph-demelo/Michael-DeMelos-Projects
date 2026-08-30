import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'homepage.dart';

class MusicPage extends StatefulWidget {
  @override
  _MusicPageState createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _filePaths = [];
  int _currentTrackIndex = 0;
  bool get _isStopped => !_audioPlayer.playing;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      if (_filePaths.isNotEmpty) {
        await _audioPlayer.setFilePath(_filePaths[_currentTrackIndex]);
      }

      _audioPlayer.playerStateStream.listen((PlayerState state) {
        setState(() {
        });

        if (_audioPlayer.playing) {
          _handleTrackCompletion();
        }
      });

      _audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer.positionStream.listen((position) {
        setState(() {
          _position = position;
        });

        if (position >= _duration) {
          _handleTrackCompletion();
        }
            });
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  void _handleTrackCompletion() {
    if (_isStopped) {
      _currentTrackIndex = (_currentTrackIndex + 1) % _filePaths.length;
      _initAudioPlayer();
      _audioPlayer.play();
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      List<String> selectedFilePaths = result.files.map((file) => file.path!).toList();
      _filePaths.addAll(selectedFilePaths);

      // If not already playing, start playing the first track in the queue
      if (!_audioPlayer.playing) {
        _currentTrackIndex = 0;
        await _initAudioPlayer();
        _audioPlayer.play();
      }
    }
  }

  void _skipTrack() {
    _currentTrackIndex = (_currentTrackIndex + 1) % _filePaths.length;
    _initAudioPlayer();
    _audioPlayer.play();
  }

  void _backTrack() {
    _currentTrackIndex = (_currentTrackIndex - 1 + _filePaths.length) % _filePaths.length;
    _initAudioPlayer();
    _audioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Music', style: TextStyle(fontWeight: FontWeight.bold,),),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display selected files in a ListView...
            Text(
              'File: ${_filePaths.isNotEmpty ? _filePaths[_currentTrackIndex].split('/').last : ''}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickFile,
              child: Text('Select Music Files'),
            ),
            SizedBox(height: 20),
            // Display total duration and playback controls...
            _buildAudioControls(),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  onPressed: _backTrack,
                ),
                IconButton(
                  icon: Icon(
                    _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    if (_audioPlayer.playing) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: _skipTrack,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioControls() {
    return Column(
      children: [
        Slider(
          value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
          onChanged: (double value) {
            _audioPlayer.seek(Duration(milliseconds: value.toInt()));
          },
          min: 0.0,
          max: _duration.inMilliseconds.toDouble(),
          label: '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: () async {
                await _audioPlayer.stop();
                _filePaths.clear(); // Clear the queue
                _currentTrackIndex = 0; // Reset current track index
                setState(() {}); // Update UI to reflect the changes
              },
            ),
            IconButton(
              icon: Icon(Icons.replay),
              onPressed: () {
                _audioPlayer.seek(Duration.zero);
                _audioPlayer.play();
              },
            ),
          ],
        ),
      ],
    );
  }
}
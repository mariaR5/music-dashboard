import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

String? _lastTitle;
String? _lastArtist;

// App runs in the background to handle incoming notifications
@pragma('vm:entry-point')
// Callback executed inside seperate background dart isolate
void _callback(NotificationEvent evt) {
  // Prevent logging every second
  if (evt.title == _lastTitle) {
    return;
  }

  final allowedPackages = {
    'com.spotify.music',
    'com.google.android.apps.youtube.music',
    'com.soundcloud.android',
  };

  // If not music notification, ignore
  if (evt.packageName == null || !allowedPackages.contains(evt.packageName)) {
    return;
  }

  _lastArtist = evt.text;
  _lastTitle = evt.title;

  print("Current song: $_lastTitle by $_lastArtist");
}

void main() {
  runApp(const MaterialApp(home: ScrobblerHome()));
}

class ScrobblerHome extends StatefulWidget {
  const ScrobblerHome({super.key});

  @override
  State<ScrobblerHome> createState() => _ScrobblerHomeState();
}

class _ScrobblerHomeState extends State<ScrobblerHome> {
  String _currentSong = "No song detected";
  String _currentPackage = "Waiting...";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Delay initialisation to avoid app crash
    Future.delayed(Duration(milliseconds: 500), () {
      initScrobbler();
    });
  }

  Future<void> initScrobbler() async {
    try {
      bool? hasPermission = await NotificationsListener.hasPermission;
      log("Has permission : $hasPermission");

      if (hasPermission == null || !hasPermission) {
        log("No permission, opening settings");
        // If no permission, open settings
        NotificationsListener.openPermissionSettings();
        return;
      }

      NotificationsListener.initialize(callbackHandle: _callback);

      // Connects background isolate to main UI isolate (recieves data from background isolate)
      NotificationsListener.receivePort?.listen((event) {
        _onDataRecieved(event);
      });

      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
      log("Service started successfully");
    } catch (e) {
      log("Initialisation Error: $e");

      if (mounted) {
        setState(() {
          _isListening = false;
          _currentSong = "Error: $e";
        });
      }
    }
  }

  void _onDataRecieved(NotificationEvent event) {
    if (event.title == null) return;

    if (mounted) {
      setState(() {
        _currentSong = event.title ?? "Unknown";
        _currentPackage = event.packageName ?? "Unknown";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notification Reader")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isListening ? "Service Running!" : "Service Inactive"),
            SizedBox(height: 5),
            Text("Last Detected Notification: "),
            Text(
              _currentSong,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 5),
            Text(
              _currentPackage,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 5),
            ElevatedButton(
              onPressed: () => NotificationsListener.openPermissionSettings(),
              child: Text("Open Permission Settings"),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

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
    initScrobbler();
  }

  // App runs in the background to handle incoming notifications
  @pragma('vm:entry-point')
  // Callback executed inside seperate background dart isolate
  static void _callback(NotificationEvent evt) {
    log("BACKGROUND: ${evt.title} by ${evt.text} [${evt.packageName}]");
  }

  Future<void> initScrobbler() async {
    bool? hasPermission = await NotificationsListener.hasPermission;
    if (!hasPermission!) {
      // If no permission, open settings
      NotificationsListener.openPermissionSettings();
      return;
    }

    try {
      NotificationsListener.initialize(callbackHandle: _callback);

      // Connects background isolate to main UI isolate (transfers data to main UI isolate)
      NotificationsListener.receivePort?.listen((event) {
        _onDataRecieved(event);
      });

      setState(() {
        _isListening = true;
      });
    } catch (e) {
      log("Initialisation Error: $e");
    }
  }

  void _onDataRecieved(NotificationEvent event) {
    if (event.title == null) return;

    // Add logic to filter out other notification keeping only songs

    setState(() {
      _currentSong = event.title ?? "Unknown";
      _currentPackage = event.packageName ?? "Unknown";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notification Reader)")),
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

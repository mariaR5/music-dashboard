import 'dart:ui';
import 'dart:isolate';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:scrobbler/dashboard_page.dart';

String? _lastTitle;
String? _lastArtist;
const String _portName =
    "notification_send_port"; // port name for communication between isolates

// App runs in the background to handle incoming notifications
@pragma('vm:entry-point')
// Callback executed inside seperate background dart isolate
void _callback(NotificationEvent evt) async {
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

  // Sending data to main UI isolate
  final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
  if (send == null) {
    print("!!UI port not found!!");
  } else {
    send.send(evt);
  }

  // Send data to python backend
  const String backendURL = "http://192.168.1.6:8000/scrobble";

  try {
    final response = await http.post(
      Uri.parse(backendURL),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": _lastTitle,
        "artist": _lastArtist,
        "package": evt.packageName,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      }),
    );
    print("Backend response: ${response.statusCode}");
  } catch (e) {
    print("Failed to send backend: $e");
  }
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
  String _songArtist = "";
  bool _isListening = false;

  final ReceivePort _port = ReceivePort();

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
      // Clear old mapping and register current port
      IsolateNameServer.removePortNameMapping(_portName);
      IsolateNameServer.registerPortWithName(_port.sendPort, _portName);

      _port.listen((dynamic data) {
        if (data is NotificationEvent) {
          _onDataRecieved(data);
        }
      });

      // Standard Permission checks
      bool? hasPermission = await NotificationsListener.hasPermission;
      print("Has permission : $hasPermission");

      if (hasPermission == null || !hasPermission) {
        print("No permission, opening settings");
        // If no permission, open settings
        NotificationsListener.openPermissionSettings();
        return;
      }

      NotificationsListener.initialize(callbackHandle: _callback);

      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
      print("Service started successfully");
    } catch (e) {
      print("Initialisation Error: $e");

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
    print("UI recieved event: ${event.title}");

    if (mounted) {
      setState(() {
        _currentSong = event.title ?? "Unknown";
        _songArtist = event.text ?? "Unknown";
        _currentPackage = event.packageName ?? "Unknown";
      });
    }
  }

  int _selectedIndex = 0; // 0 = Home 1= Dashboard

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Page 1 : Home page
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isListening ? "Service Running!" : "Service Inactive"),
            SizedBox(height: 5),
            Text("Last Detected Notification: "),
            Text(
              "$_currentSong - $_songArtist",
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

      // Page 2 : Dashboard
      const DashboardPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text("Universal Scrobbler")),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() {
          _selectedIndex = index;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.hearing), label: "Live"),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "Dashbaord",
          ),
        ],
      ),
    );
  }
}

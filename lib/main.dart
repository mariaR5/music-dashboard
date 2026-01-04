import 'dart:ui';
import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:scrobbler/pages/dashboard_page.dart';
import 'package:scrobbler/pages/home_page.dart';
import 'package:scrobbler/pages/recommendation_page.dart';
import 'package:scrobbler/pages/splash_screen.dart';
import 'package:scrobbler/services/auth_service.dart';
import 'package:scrobbler/widgets/custom_navbar.dart';

String? _lastTitle;
String? _lastArtist;
Timer? _scrobbleTimer;
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

  bool isMediaNotification = _isMediaNotification(evt);

  if (!isMediaNotification) {
    return;
  }

  _lastArtist = evt.text;
  _lastTitle = evt.title;

  print("Detect: $_lastTitle by $_lastArtist (Waiting 30s to confirm)");

  // Sending data to main UI isolate
  final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
  if (send == null) {
    print("!!UI port not found!!");
  } else {
    send.send(evt);
  }

  // Cancel previous song's timer
  _scrobbleTimer?.cancel();

  // Send data to backend only if user listens to atleast 30 seconds
  _scrobbleTimer = Timer(const Duration(seconds: 30), () async {
    print("Scrobble confirmed: $_lastTitle");

    // Send data to python backend
    final String backendURL = dotenv.env['API_BASE_URL']!;

    // Get token from flutter storage
    final token = await AuthService.getToken();

    try {
      final response = await http.post(
        Uri.parse('$backendURL/scrobble'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
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
  });
}

bool _isMediaNotification(NotificationEvent evt) {
  final allowedPackages = {
    'com.spotify.music',
    'com.google.android.apps.youtube.music',
    'com.soundcloud.android',

    // Local music players
    'com.android.music', // Stock Android Music
    'com.miui.player', // Xiaomi Music
    'com.samsung.android.app.music', // Samsung Music
    'com.maxmpz.audioplayer', // Poweramp
    'com.apple.android.music', // Apple Music
    'com.aspiro.tidal', // TIDAL
    'deezer.android.app', // Deezer
    'com.sec.android.app.music', // Samsung Music (alt)
    'com.asus.music', // ASUS Music
    'com.oppo.music', // OPPO Music
    'com.oneplus.music', // OnePlus Music
    'com.lge.music', // LG Music
    'com.sony.walkman.music', // Sony Walkman
  };

  String? packageName = evt.packageName;

  // If not music notification, ignore
  if (packageName == null) {
    return false;
  }

  if (allowedPackages.contains(packageName)) {
    return true;
  }

  final musicKeywords = ['music', 'player', 'audio', 'media', 'tune', 'sound'];
  for (String keyword in musicKeywords) {
    if (packageName.toLowerCase().contains(keyword)) {
      if (evt.title != null && evt.title!.isNotEmpty) {
        return true;
      }
    }
  }

  return false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    MaterialApp(
      theme: ThemeData(
        fontFamily: 'NotoSans',
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF1A1A1A),
          onPrimary: Colors.white,
          secondary: Color(0xFF697565),
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Color(0xFF3B3B3B),
          onSurface: Colors.grey,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    ),
  );
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
    final List<Widget> _pages = [
      // Page 1 : Home page
      HomePage(
        currentTitle: _currentSong,
        currentArtist: _songArtist,
        currentPackage: _currentPackage,
        isServiceRunning: _isListening,
      ),

      // Page 2 : Recommendations
      const RecommendationPage(),

      // Page 3 : Dashboard
      const DashboardPage(),
    ];

    void onItemTapped(int index) {
      setState(() {
        _selectedIndex = index;
      });
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: CustomNavbar(
        selectedIndex: _selectedIndex,
        onItemSelected: onItemTapped,
      ),
    );
  }
}

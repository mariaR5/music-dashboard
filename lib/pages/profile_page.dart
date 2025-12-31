import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:scrobbler/pages/login_page.dart';
import 'package:scrobbler/services/auth_service.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:scrobbler/widgets/form_fields.dart';
import 'package:scrobbler/widgets/menu_item.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = 'Loading...';
  String _email = '...';
  String _joinedDate = '...';
  bool _isLoading = true;

  final bgGrey = Color(0xFF1A1A1A);
  final sageGreen = Color(0xFF697565);

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final baseUrl = dotenv.env['API_BASE_URL'];

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _username = data['username'];
            _email = data['email'] ?? 'No email';
            String rawDate = data['created_at'] ?? DateTime.now().toString();
            _joinedDate = rawDate.split('T')[0];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _username = 'Unknown user';
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAllowedPackages() {
    Map<String, String> appNameMap = {
      'com.spotify.music': 'Spotify',
      'com.google.android.apps.youtube.music': 'YouTube Music',
      'com.soundcloud.android': 'SoundCloud',
      'com.apple.android.music': 'Apple Music',
      'com.aspiro.tidal': 'TIDAL',
      'deezer.android.app': 'Deezer',
      'com.maxmpz.audioplayer': 'Poweramp',
      'com.samsung.android.app.music': 'Samsung Music',
      'com.sec.android.app.music': 'Samsung Music',
      'com.miui.player': 'Mi Music',
      'com.oppo.music': 'OPPO Music',
      'com.oneplus.music': 'OnePlus Music',
      'com.lge.music': 'LG Music',
      'com.sony.walkman.music': 'Sony Walkman',
    };
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgGrey,
        title: const Text(
          'Supported platforms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: appNameMap.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        entry.key,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Colors.grey),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Clear Listening History?',
      content:
          'This will permanently delete all your listening stats. This cannot be undone.',
      confirmText: 'Clear All',
      isDanger: true,
    );

    if (confirmed != true) return;

    final baseUrl = dotenv.env['API_BASE_URL']!;
    final token = await AuthService.getToken();

    await http.delete(
      Uri.parse('$baseUrl/history/clear'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('History Cleared')));
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Account?',
      content:
          "This will permanently delete your account and all associated data. You cannot recover this.",
      confirmText: 'Delete',
      isDanger: true,
    );

    if (confirmed != true) return;

    final baseUrl = dotenv.env['API_BASE_URL']!;
    final token = await AuthService.getToken();

    await http.delete(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    _logout();
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Logout?',
      content: 'Are you sure you want to log ou?',
      confirmText: 'Log Out',
    );

    if (confirmed != true) return;

    await AuthService.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDanger = false,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgGrey,
        content: Text(content, style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmText,
              style: TextStyle(color: isDanger ? Colors.red : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const sageGreen = Color(0xFF697565);
    const bgGrey = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sageGreen,
                        ),
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _username,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(_email, style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            'Listening since $_joinedDate',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Expanded(
                    child: ListView(
                      children: [
                        const Divider(height: 1, color: Colors.grey),
                        MenuItem(
                          title: 'Supported Packages',
                          subtitle:
                              'Music listening platforms this app supports',
                          onTap: _showAllowedPackages,
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        MenuItem(
                          title: 'Permission Settings',
                          subtitle:
                              'Open notification permission settings on your device',
                          onTap: NotificationsListener.openPermissionSettings,
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        MenuItem(
                          title: 'Clear Listening History',
                          subtitle: "Delete all data from your account",
                          onTap: _clearHistory,
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        MenuItem(
                          title: "Delete Account",
                          subtitle: "Delete your account from our database",
                          onTap: _deleteAccount,
                        ),
                        const Divider(height: 1, color: Colors.grey),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: SubmitButton(label: 'Logout', onTap: _logout),
                  ),
                ],
              ),
            ),
    );
  }
}

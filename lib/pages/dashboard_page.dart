import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/models/stats_model.dart';
import 'package:scrobbler/widgets/stat_card.dart';
import 'package:scrobbler/widgets/stats_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String baseUrl = dotenv.env['API_BASE_URL']!;

  int _totalPlays = 0;
  int _totalMinutes = 0;
  List<TopSong> _topSongs = [];
  List<TopArtist> _topArtists = [];

  int _selectedMonth = 0; // 0: All time, 1: Jan, 2: Feb,.....

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    String queryParams = ""; // empty query for all time
    if (_selectedMonth != 0) {
      queryParams = "?month=$_selectedMonth&year=2025";
    }

    try {
      // Fetch data from server
      final resTotal = await http.get(
        Uri.parse("$baseUrl/stats/total$queryParams"),
      );
      final resSongs = await http.get(
        Uri.parse("$baseUrl/stats/top-songs$queryParams"),
      );
      final resArtists = await http.get(
        Uri.parse("$baseUrl/stats/top-artists$queryParams"),
      );

      if (resTotal.statusCode == 200 &&
          resArtists.statusCode == 200 &&
          resSongs.statusCode == 200) {
        setState(() {
          _totalPlays = jsonDecode(resTotal.body)["total_plays"];
          _totalMinutes = jsonDecode(resTotal.body)["total_minutes"];

          final List<dynamic> songList = jsonDecode(resSongs.body);
          _topSongs = songList.map((e) => TopSong.fromJson(e)).toList();

          final List<dynamic> artistList = jsonDecode(resArtists.body);
          _topArtists = artistList.map((e) => TopArtist.fromJson(e)).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching stats: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _lauchSpotify(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color sageGreen = Color(0xFF697565);
    final Color bgGrey = const Color(0xFF1A1A1A);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgGrey,
        surfaceTintColor: sageGreen,
        elevation: 12,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<int>(
              value: _selectedMonth,
              icon: Icon(Icons.filter_alt, color: sageGreen, size: 28),
              underline: Container(),
              items: [
                DropdownMenuItem(value: 0, child: Text("All Time")),
                DropdownMenuItem(value: 11, child: Text("November")),
                DropdownMenuItem(value: 12, child: Text("December")),
              ],
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedMonth = newValue;
                  });
                  fetchStats();
                }
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Your Listening Vibe",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                //---Total Plays---
                Expanded(
                  child: StatCard(
                    title: 'Total Plays',
                    value: _totalPlays,
                    sageGreen: sageGreen,
                  ),
                ),
                const SizedBox(width: 16),
                //---Total Minutes
                Expanded(
                  child: StatCard(
                    title: 'Minutes Listened',
                    value: _totalMinutes,
                    sageGreen: sageGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
            //---Top Songs---
            const Text(
              "Top Songs",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TopSongsList(topSongs: _topSongs),

            const SizedBox(height: 40),

            //---Top Artists---
            const Text(
              "Top Artists",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TopArtistsList(topArtists: _topArtists),
          ],
        ),
      ),
    );
  }
}

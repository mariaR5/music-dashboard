import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/stats_model.dart';
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Your listening vibe",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<int>(
              value: _selectedMonth,
              icon: Icon(Icons.filter_alt, color: Colors.black, size: 28),
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
            //---Total Plays---
            _buildStatCard("Total Plays", "$_totalPlays", Colors.red),
            const SizedBox(height: 10),

            //---Total Minutes
            _buildStatCard('Minutes Listened', "$_totalMinutes", Colors.green),
            const SizedBox(height: 30),

            //---Top Songs---
            const Text(
              "Top 5 songs",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._topSongs.map(
              (song) => ListTile(
                leading: song.imageUrl != null
                    ? Image.network(
                        song.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.music_note),
                title: Text(
                  song.title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(song.artist),
                trailing: Text("${song.plays} plays"),
              ),
            ),

            const SizedBox(height: 20),

            //---Top Artists---
            const Text(
              "Top 5 artists",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._topArtists.map(
              (artist) => Card(
                child: ListTile(
                  leading: artist.artistImage != null
                      ? CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(artist.artistImage!),
                        )
                      : const Icon(Icons.person),
                  title: Text(
                    artist.artist,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text("${artist.plays} plays"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

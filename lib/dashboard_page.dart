import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/stats_model.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String baseUrl = "http://192.168.1.6:8000";

  int _totalPlays = 0;
  List<TopSong> _topSongs = [];
  List<TopArtist> _topArtists = [];
  bool _isLoading = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      // Fetch data from server
      final resTotal = await http.get(Uri.parse("$baseUrl/stats/total"));
      final resSongs = await http.get(Uri.parse("$baseUrl/stats/top-songs"));
      final resArtists = await http.get(
        Uri.parse("$baseUrl/stats/top-artists"),
      );

      if (resTotal.statusCode == 200 &&
          resArtists.statusCode == 200 &&
          resSongs.statusCode == 200) {
        setState(() {
          _totalPlays = jsonDecode(resTotal.body)["total_plays"];

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text("Your listening vibe")),
      body: RefreshIndicator(
        onRefresh: fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            //---Total Plays---
            _buildStatCard("Total Plays", "$_totalPlays", Colors.blue),
            const SizedBox(height: 20),

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

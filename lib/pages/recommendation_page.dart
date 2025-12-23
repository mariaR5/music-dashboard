import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final String baseUrl = dotenv.env['API_BASE_URL']!;

  List<dynamic> _flowRecs = [];
  List<dynamic> _lyricRecs = [];
  List<dynamic> _creditRecs = [];
  List<dynamic> _artistRecs = [];
  List<dynamic> _sampleRecs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRecommendations();
  }

  Future<void> fetchRecommendations() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse("$baseUrl/recommend/vibes")),
        http.get(Uri.parse("$baseUrl/recommend/lyrics")),
        http.get(Uri.parse("$baseUrl/recommend/credits")),
        http.get(Uri.parse("$baseUrl/recommend/artists")),
        http.get(Uri.parse("$baseUrl/recommend/samples")),
      ]);

      if (mounted) {
        setState(() {
          // Process flow recs
          if (results[0].statusCode == 200) {
            _flowRecs = jsonDecode(results[0].body);
          }
          if (results[1].statusCode == 200) {
            _lyricRecs = jsonDecode(results[1].body);
          }
          if (results[2].statusCode == 200) {
            _creditRecs = jsonDecode(results[2].body);
          }
          if (results[3].statusCode == 200) {
            _artistRecs = jsonDecode(results[3].body);
          }
          if (results[4].statusCode == 200) {
            _sampleRecs = jsonDecode(results[4].body);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching recommendations: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchSpotify(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: Text("Discover")),
      body: RefreshIndicator(
        onRefresh: fetchRecommendations,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Flow recommendation
            if (_flowRecs.isNotEmpty) ...[
              Text(
                _flowRecs[0]['reason'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _flowRecs.length,
                  itemBuilder: (context, index) {
                    final song = _flowRecs[index];
                    return GestureDetector(
                      onTap: () {
                        if (song["spotify_url"] != null) {
                          _launchSpotify(song["spotify_url"]);
                        } else {
                          print("Cant launch spotify");
                        }
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song["image_url"],
                                height: 140,
                                width: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song["title"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              song["artist"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Lyrical recommendations
            if (_lyricRecs.isNotEmpty) ...[
              Text(
                _lyricRecs[0]['reason'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _lyricRecs.length,
                  itemBuilder: (context, index) {
                    final song = _lyricRecs[index];
                    return GestureDetector(
                      onTap: () {
                        if (song["spotify_url"] != null) {
                          _launchSpotify(song["spotify_url"]);
                        } else {
                          print("Cant launch spotify");
                        }
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song["image_url"],
                                height: 140,
                                width: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song["title"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              song["artist"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Credit Recommendations
            if (_creditRecs.isNotEmpty) ...[
              Text(
                _creditRecs[0]['reason'] ?? '',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _creditRecs.length,
                  itemBuilder: (context, index) {
                    final song = _creditRecs[index];
                    return GestureDetector(
                      onTap: () {
                        if (song["spotify_url"] != null) {
                          _launchSpotify(song["spotify_url"]);
                        } else {
                          print("Cant launch spotify");
                        }
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song["image_url"],
                                height: 140,
                                width: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song["title"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              song["artist"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Artist Recommendations
            if (_artistRecs.isNotEmpty) ...[
              Text(
                _artistRecs[0]['reason'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _artistRecs.length,
                  itemBuilder: (context, index) {
                    final song = _artistRecs[index];
                    return GestureDetector(
                      onTap: () {
                        if (song["spotify_url"] != null) {
                          _launchSpotify(song["spotify_url"]);
                        } else {
                          print("Cant launch spotify");
                        }
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 70,
                              backgroundImage: NetworkImage(
                                song['artist_image'],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song["artist"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Sample recommendation
            if (_sampleRecs.isNotEmpty) ...[
              Text(
                _sampleRecs[0]['reason'] ?? '',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampleRecs.length,
                  itemBuilder: (context, index) {
                    final song = _sampleRecs[index];
                    return GestureDetector(
                      onTap: () {
                        if (song["spotify_url"] != null) {
                          _launchSpotify(song["spotify_url"]);
                        } else {
                          print("Cant launch spotify");
                        }
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song["image_url"],
                                height: 140,
                                width: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song["title"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              song["artist"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              song["reason"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

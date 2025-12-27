import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/models/scrobble.dart';
import 'package:scrobbler/services/auth_service.dart';
import 'package:scrobbler/widgets/recommend_section.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final String baseUrl = dotenv.env['API_BASE_URL']!;

  List<Scrobble> _flowRecs = [];
  List<Scrobble> _lyricRecs = [];
  List<Scrobble> _creditRecs = [];
  List<Scrobble> _artistRecs = [];
  List<Scrobble> _sampleRecs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRecommendations();
  }

  Future<void> fetchRecommendations() async {
    try {
      final token = await AuthService.getToken();

      final results = await Future.wait([
        http.get(
          Uri.parse("$baseUrl/recommend/vibes"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("$baseUrl/recommend/lyrics"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("$baseUrl/recommend/credits"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("$baseUrl/recommend/artists"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("$baseUrl/recommend/samples"),
          headers: {"Authorization": "Bearer $token"},
        ),
      ]);

      if (mounted) {
        setState(() {
          // Process flow recs
          if (results[0].statusCode == 200) {
            final List<dynamic> data = jsonDecode(results[0].body);
            _flowRecs = data.map((json) => Scrobble.fromJson(json)).toList();
          }
          if (results[1].statusCode == 200) {
            final List<dynamic> data = jsonDecode(results[1].body);
            _lyricRecs = data.map((json) => Scrobble.fromJson(json)).toList();
          }
          if (results[2].statusCode == 200) {
            final List<dynamic> data = jsonDecode(results[2].body);
            _creditRecs = data.map((json) => Scrobble.fromJson(json)).toList();
          }
          if (results[3].statusCode == 200) {
            final List<dynamic> data = jsonDecode(results[3].body);
            _artistRecs = data.map((json) => Scrobble.fromJson(json)).toList();
          }
          if (results[4].statusCode == 200) {
            final List<dynamic> data = jsonDecode(results[4].body);
            _sampleRecs = data.map((json) => Scrobble.fromJson(json)).toList();
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
      body: RefreshIndicator(
        onRefresh: fetchRecommendations,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 20),
              Text(
                'For You...',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              // 1. Vibe Recommender
              if (_flowRecs.isNotEmpty)
                RecommendSection(
                  title: _flowRecs.first.reason ?? '',
                  items: _flowRecs,
                  onTap: _launchSpotify,
                ),
              const SizedBox(height: 30),
              // 2. Lyrical Recommender
              if (_lyricRecs.isNotEmpty)
                RecommendSection(
                  title: _lyricRecs.first.reason ?? '',
                  items: _lyricRecs,
                  onTap: _launchSpotify,
                ),
              const SizedBox(height: 30),
              // 3. Artist Recommender
              if (_artistRecs.isNotEmpty)
                RecommendSection(
                  title: _artistRecs.first.reason ?? '',
                  items: _artistRecs,
                  onTap: _launchSpotify,
                  circularImage: true,
                ),

              // 4. Credits Recommender
              if (_creditRecs.isNotEmpty)
                RecommendSection(
                  title: _creditRecs.first.reason ?? '',
                  items: _creditRecs,
                  onTap: _launchSpotify,
                ),
              const SizedBox(height: 30),
              // 5. Sample Recommender
              if (_sampleRecs.isNotEmpty)
                RecommendSection(
                  title: 'Samples of your favorites',
                  items: _sampleRecs,
                  showItemReason: true,
                  onTap: _launchSpotify,
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

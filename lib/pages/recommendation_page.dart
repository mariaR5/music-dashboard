import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
              RecommendSection(
                title: _flowRecs[0]['reason'],
                items: _flowRecs,
                onTap: _launchSpotify,
              ),

              // 2. Lyrical Recommender
              RecommendSection(
                title: _lyricRecs[0]['reason'],
                items: _lyricRecs,
                onTap: _launchSpotify,
              ),

              // 3. Artist Recommender
              RecommendSection(
                title: _artistRecs[0]['reason'],
                items: _artistRecs,
                onTap: _launchSpotify,
                circularImage: true,
              ),

              // 4. Credits Recommender
              RecommendSection(
                title: _creditRecs[0]['reason'] ?? '',
                items: _creditRecs,
                onTap: _launchSpotify,
              ),

              // 5. Sample Recommender
              RecommendSection(
                title: _sampleRecs[0]['reason'] ?? '',
                items: _sampleRecs,
                showItemReason: true,
                onTap: _launchSpotify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

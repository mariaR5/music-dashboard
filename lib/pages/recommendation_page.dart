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

  List<Scrobble> _parseRecs(http.Response response) {
    if (response.statusCode != 200) return [];

    try {
      final dynamic decoded = jsonDecode(response.body);

      // If backend returns a map
      if (decoded is Map) return [];

      // If backend returns a list
      if (decoded is List) {
        if (decoded.isEmpty) return [];

        // Check if first item is a message object
        if (decoded[0] is Map && decoded[0].containsKey('message')) return [];
      }

      return (decoded as List).map((json) => Scrobble.fromJson(json)).toList();
    } catch (e) {
      print('Parse error : $e');
    }
    return [];
  }

  Future<void> fetchRecommendations() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      final headers = {"Authorization": "Bearer $token"};

      final results = await Future.wait([
        http.get(Uri.parse("$baseUrl/recommend/vibes"), headers: headers),
        http.get(Uri.parse("$baseUrl/recommend/lyrics"), headers: headers),
        http.get(Uri.parse("$baseUrl/recommend/credits"), headers: headers),
        http.get(Uri.parse("$baseUrl/recommend/artists"), headers: headers),
        http.get(Uri.parse("$baseUrl/recommend/samples"), headers: headers),
      ]);

      if (mounted) {
        setState(() {
          // Process flow recs
          _flowRecs = _parseRecs(results[0]);
          _lyricRecs = _parseRecs(results[1]);
          _creditRecs = _parseRecs(results[2]);
          _artistRecs = _parseRecs(results[3]);
          _sampleRecs = _parseRecs(results[4]);
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
    final colors = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final bool isEmpty =
        _flowRecs.isEmpty &&
        _lyricRecs.isEmpty &&
        _creditRecs.isEmpty &&
        _artistRecs.isEmpty &&
        _sampleRecs.isEmpty;

    if (isEmpty) {
      return Scaffold(
        body: Center(child: Text('Listen to some music and check back later')),
      );
    }

    return Scaffold(
      backgroundColor: colors.primary,
      appBar: AppBar(title: Text('Discover similar music')),
      body: RefreshIndicator(
        color: Colors.white,
        onRefresh: fetchRecommendations,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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

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

  List<Scrobble>? _flowRecs;
  List<Scrobble>? _lyricRecs;
  List<Scrobble>? _creditRecs;
  List<Scrobble>? _artistRecs;
  List<Scrobble>? _sampleRecs;

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  Future<void> fetchAll() async {
    // Set to null to show loaders
    setState(() {
      _flowRecs = null;
      _lyricRecs = null;
      _creditRecs = null;
      _artistRecs = null;
      _sampleRecs = null;
    });

    final token = await AuthService.getToken();
    final headers = {"Authorization": "Bearer $token"};

    // Send all requests in parallel
    _fetchCategory('vibes', headers, (data) => _flowRecs = data);
    _fetchCategory('lyrics', headers, (data) => _lyricRecs = data);
    _fetchCategory('credits', headers, (data) => _creditRecs = data);
    _fetchCategory('artists', headers, (data) => _artistRecs = data);
    _fetchCategory('samples', headers, (data) => _sampleRecs = data);
  }

  Future<void> _fetchCategory(
    String endpoint,
    Map<String, String> headers,
    Function(List<Scrobble>) updateState,
  ) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/recommend/$endpoint"),
        headers: headers,
      );
      final data = _parseRecs(response);

      if (mounted) {
        setState(() {
          updateState(data);
        });
      }
    } catch (e) {
      print("Error fetching $endpoint: $e");
      if (mounted) {
        setState(() {
          updateState([]); // On error, set to empty so that loader disappears
        });
      }
    }
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

  Future<void> _launchSpotify(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $url");
    }
  }

  Widget _buildSectionLoader({
    required List<Scrobble>? items,
    required String? defaultTitle,
    bool circular = false,
    bool showReason = false,
  }) {
    // Loading state
    if (items == null) {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 30),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Empty state
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Data state
    final title = defaultTitle ?? items.first.reason;

    return Column(
      children: [
        RecommendSection(
          title: title!,
          items: items,
          onTap: _launchSpotify,
          circularImage: circular,
          showItemReason: showReason,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.primary,
      appBar: AppBar(title: Text('Discover similar music')),
      body: RefreshIndicator(
        color: Colors.white,
        onRefresh: fetchAll,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Vibe Recommender
              _buildSectionLoader(items: _flowRecs, defaultTitle: null),

              // 2. Lyrical Recommender
              _buildSectionLoader(items: _lyricRecs, defaultTitle: null),

              // 3. Artist Recommender
              _buildSectionLoader(
                items: _artistRecs,
                defaultTitle: null,
                circular: true,
              ),

              // 4. Credits Recommender
              _buildSectionLoader(items: _creditRecs, defaultTitle: null),

              // 5. Sample Recommender
              _buildSectionLoader(
                items: _sampleRecs,
                defaultTitle: 'Samples of your favorites',
                showReason: true,
              ),

              if (_flowRecs != null &&
                  _flowRecs!.isEmpty &&
                  _lyricRecs != null &&
                  _lyricRecs!.isEmpty &&
                  _creditRecs != null &&
                  _creditRecs!.isEmpty &&
                  _artistRecs != null &&
                  _artistRecs!.isEmpty &&
                  _sampleRecs != null &&
                  _sampleRecs!.isEmpty)
                const Center(
                  child: Text('Listen to more music to get recommendations'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

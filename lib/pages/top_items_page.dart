import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:scrobbler/models/stats_model.dart';
import 'package:scrobbler/services/auth_service.dart';
import 'package:scrobbler/widgets/stats_list.dart';

class TopItemsPage extends StatefulWidget {
  final String title;
  final String type;
  final int month;
  final int year;

  const TopItemsPage({
    super.key,
    required this.title,
    required this.type,
    required this.month,
    required this.year,
  });

  @override
  State<TopItemsPage> createState() => _TopItemsPageState();
}

class _TopItemsPageState extends State<TopItemsPage> {
  final String baseUrl = dotenv.env['API_BASE_URL']!;
  bool _isLoading = true;
  List<TopSong> _songs = [];
  List<TopArtist> _artists = [];

  @override
  void initState() {
    super.initState();
    _fetchMoreData();
  }

  Future<void> _fetchMoreData() async {
    String queryParams = '?limit=50';
    if (widget.month != 0) {
      queryParams += '&month=${widget.month}&year=${widget.year}';
    }

    final endpoint = widget.type == 'songs' ? 'top-songs' : 'top-artists';

    try {
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse("$baseUrl/stats/$endpoint$queryParams"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          final List<dynamic> data = jsonDecode(response.body);
          if (widget.type == 'songs') {
            _songs = data.map((e) => TopSong.fromJson(e)).toList();
          } else {
            _artists = data.map((e) => TopArtist.fromJson(e)).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading page: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: widget.type == 'songs'
                  ? TopSongsList(topSongs: _songs)
                  : TopArtistsList(topArtists: _artists),
            ),
    );
  }
}

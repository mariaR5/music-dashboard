import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:scrobbler/models/scrobble.dart';

import '../models/daily_stats.dart';

class MusicService {
  final String baseUrl = dotenv.env['API_BASE_URL']!;

  // Get track's album art from endpoint
  Future<String?> getAlbumArt(String title, String artist) async {
    if (title == 'No song detected' || title.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '$baseUrl/track/image',
      ).replace(queryParameters: {'title': title, 'artist': artist});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image_url'];
      }
    } catch (e) {
      print('Error fetching album art: $e');
    }
    return null;
  }

  // Get 10 recently played songs
  Future<List<Scrobble>> getRecentlyPlayed() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history?limit=10'));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => Scrobble.fromJson(item)).toList();
      } else {
        throw Exception('Failed to laod history');
      }
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  // Get today stats
  Future<DailyStats> getTodayStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats/today'));

      if (response.statusCode == 200) {
        return DailyStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      print('Error: $e');
      return DailyStats(totalPlays: 0, minutesListened: 0, topArtistName: '-');
    }
  }
}

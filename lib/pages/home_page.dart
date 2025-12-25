import 'package:flutter/material.dart';
import 'package:scrobbler/models/daily_stats.dart';
import 'package:scrobbler/models/scrobble.dart';
import 'package:scrobbler/services/music_service.dart';
import 'package:scrobbler/widgets/artist_card.dart';
import 'package:scrobbler/widgets/recommend_section.dart';
import 'package:scrobbler/widgets/stat_card.dart';

import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final String currentTitle;
  final String currentArtist;
  final String currentPackage;
  final bool isServiceRunning;

  const HomePage({
    super.key,
    required this.currentTitle,
    required this.currentArtist,
    required this.currentPackage,
    required this.isServiceRunning,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color sageGreen = const Color(0xFF697565);
  final Color bgGrey = const Color(0xFF1A1A1A);

  final MusicService _musicService = MusicService();

  String? _currentTrackImage;
  bool _isImageLoading = false;

  // State varibles
  bool _isLoading = true;
  List<Scrobble> _recentSongs = [];
  DailyStats? _todayStats;

  void initState() {
    super.initState();
    _loadData();
    _fetchTrackImage();
  }

  // Change track image when widget is updated (ie new song)
  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentTitle != widget.currentTitle ||
        oldWidget.currentArtist != widget.currentArtist) {
      _fetchTrackImage();
    }
  }

  Future<void> _fetchTrackImage() async {
    setState(() {
      _isImageLoading = true;
    });

    // Fetch the album art from service by passing title and artist from the widget
    String? url = await _musicService.getAlbumArt(
      widget.currentTitle,
      widget.currentArtist,
    );
    if (mounted) {
      setState(() {
        _currentTrackImage = url;
        _isImageLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    // Run requests
    final results = await Future.wait([
      _musicService.getRecentlyPlayed(),
      _musicService.getTodayStats(),
    ]);

    if (mounted) {
      setState(() {
        _todayStats = results[1] as DailyStats;
        _recentSongs = results[0] as List<Scrobble>;
        _isLoading = false;
      });
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
    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // Top status badge and profile icon
              SliverPadding(
                padding: EdgeInsetsGeometry.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: sageGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Playing on spotify',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: sageGreen,
                        child: Icon(Icons.person),
                      ),
                    ],
                  ),
                ),
              ),

              //=======Now playing block========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Now Playing...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Album art, song name and artist
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 200,
                              width: 200,
                              color: sageGreen,
                              child: ClipRRect(
                                child: _currentTrackImage != null
                                    ? Image.network(
                                        _currentTrackImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.music_note),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.currentTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              widget.currentArtist,
                              style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              //=========== Recently Played ================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RecommendSection(
                    title: "Recently Played",
                    items: _recentSongs,
                    onTap: _launchSpotify,
                  ),
                ),
              ),

              //========= Today at a glance ============
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        "Today at a Glance",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Top artist
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sageGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ArtistCard(
                            title: "Top Artist",
                            artist: _todayStats?.topArtistName ?? '-',
                            imageUrl: _todayStats?.topArtistImage,
                            sageGreen: sageGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          //---Total Plays---
                          Expanded(
                            child: StatCard(
                              title: 'Total Plays',
                              value: _todayStats?.totalPlays ?? 0,
                              sageGreen: sageGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          //---Total Minutes
                          Expanded(
                            child: StatCard(
                              title: 'Minutes Listened',
                              value: _todayStats?.minutesListened ?? 0,
                              sageGreen: sageGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

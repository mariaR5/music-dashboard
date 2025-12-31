import 'package:flutter/material.dart';
import 'package:scrobbler/models/daily_stats.dart';
import 'package:scrobbler/models/scrobble.dart';
import 'package:scrobbler/pages/profile_page.dart';
import 'package:scrobbler/services/music_service.dart';
import 'package:scrobbler/widgets/artist_card.dart';
import 'package:scrobbler/widgets/now_playing.dart';
import 'package:scrobbler/widgets/recommend_section.dart';
import 'package:scrobbler/widgets/stat_card.dart';
import 'package:scrobbler/widgets/status_card.dart';

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
              //=========Top status badge and profile icon=============
              SliverPadding(
                padding: EdgeInsetsGeometry.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF3B3B3B),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ),

                      StatusCard(
                        isServiceRunning: widget.isServiceRunning,
                        currentPackage: widget.currentPackage,
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
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      NowPlaying(
                        title: widget.currentTitle,
                        artist: widget.currentArtist,
                        imageUrl: _currentTrackImage,
                        isAnimating:
                            widget.isServiceRunning &&
                            widget.currentTitle != 'No song detected',
                      ),
                      const SizedBox(height: 8),
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
                      ArtistCard(
                        title: "Top Artist",
                        artist: _todayStats?.topArtistName ?? '-',
                        imageUrl: _todayStats?.topArtistImage,
                        sageGreen: sageGreen,
                      ),
                      const SizedBox(height: 8),

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
                          const SizedBox(width: 8),
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

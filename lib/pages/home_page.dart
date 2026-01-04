import 'package:flutter/material.dart';
import 'package:scrobbler/models/daily_stats.dart';
import 'package:scrobbler/models/scrobble.dart';
import 'package:scrobbler/pages/profile_page.dart';
import 'package:scrobbler/services/music_service.dart';
import 'package:scrobbler/widgets/artist_card.dart';
import 'package:scrobbler/widgets/info_bullet.dart';
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

  void _showInfoDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoBullet(
                  title: 'How it works',
                  text:
                      "This app reads the 'Now Playing' notifications from your status bar. It only detects music from the apps listed in your Profile > Allowed Packages.",
                ),
                SizedBox(height: 16),
                InfoBullet(
                  title: "Keep it running",
                  text:
                      "The app must be open in the background to detect songs. For the best experience, lock this app in your 'Recent Apps' screen so your phone doesn't close it to save battery.",
                ),
                SizedBox(height: 16),
                InfoBullet(
                  title: "Looping Songs",
                  text:
                      "If you play the exact same song multiple times in a row (Loop Mode), it counts as 1 play. The song title must change for a new scrobble to trigger.",
                ),
                SizedBox(height: 16),
                InfoBullet(
                  title: "The 30-Second Rule",
                  text:
                      "You must listen to a song for at least 30 seconds. If you skip before that, it won't be saved.",
                ),
                SizedBox(height: 16),
                InfoBullet(
                  title: "Database Requirement",
                  text:
                      "Only songs that can be matched to a track on Spotify will be saved to your history and stats.",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.primary,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : CustomScrollView(
                  slivers: [
                    //=========Top status badge and profile icon=============
                    SliverPadding(
                      padding: EdgeInsetsGeometry.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
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
                                  backgroundColor: colors.surface,
                                  backgroundImage: AssetImage(
                                    'assets/images/avatar.jpeg',
                                  ),
                                ),
                              ),
                            ),

                            StatusCard(
                              isServiceRunning: widget.isServiceRunning,
                              currentPackage: widget.currentPackage,
                            ),
                            IconButton(
                              icon: Icon(Icons.info_outline, size: 30),
                              onPressed: () => _showInfoDialog(context),
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
                            const SizedBox(height: 36),

                            NowPlaying(
                              title: widget.currentTitle,
                              artist: widget.currentArtist,
                              imageUrl: _currentTrackImage,
                              isLoading: _isImageLoading,
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                //---Total Minutes
                                Expanded(
                                  child: StatCard(
                                    title: 'Minutes Listened',
                                    value: _todayStats?.minutesListened ?? 0,
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

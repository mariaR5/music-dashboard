import 'package:flutter/material.dart';
import 'package:scrobbler/models/daily_stats.dart';
import 'package:scrobbler/models/scrobble.dart';
import 'package:scrobbler/services/music_service.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        "Recently Played",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Horizontal List
                      SizedBox(
                        height: 200,
                        child: _recentSongs.isEmpty
                            ? Center(child: Text("No history yet"))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentSongs.length,
                                itemBuilder: (context, index) {
                                  final song = _recentSongs[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Album art
                                        SizedBox(
                                          width: 150,
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: song.imageUrl != null
                                                  ? Image.network(
                                                      song.imageUrl!,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Icon(Icons.music_note),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Song name
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            song.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            song.artist,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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
                          child: Row(
                            children: [
                              // Artist Image
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: sageGreen,
                                backgroundImage:
                                    _todayStats?.topArtistImage != null
                                    ? NetworkImage(_todayStats!.topArtistImage!)
                                    : null,
                                child: _todayStats?.topArtistImage == null
                                    ? Icon(Icons.person)
                                    : null,
                              ),

                              const SizedBox(width: 36),

                              // Text
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Top Artist',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _todayStats?.topArtistName ?? "-",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: sageGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Total Plays',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_todayStats?.totalPlays ?? 0}',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: sageGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Minutes Listened',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_todayStats?.minutesListened ?? 0}',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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

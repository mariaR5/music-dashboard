class DailyStats {
  final int totalPlays;
  final int minutesListened;
  final String topArtistName;
  final String? topArtistImage;

  DailyStats({
    required this.totalPlays,
    required this.minutesListened,
    required this.topArtistName,
    this.topArtistImage,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      totalPlays: json['total_plays'] ?? 0,
      minutesListened: json['minutes_listened'] ?? 0,
      topArtistName: json['top_artist_name'] ?? 'No data',
      topArtistImage: json['top_artist_image'],
    );
  }
}

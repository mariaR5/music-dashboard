class Scrobble {
  final String title;
  final String artist;
  final String? imageUrl;
  final String? spotifyUrl;
  final String? reason;

  Scrobble({
    required this.title,
    required this.artist,
    this.imageUrl,
    this.spotifyUrl,
    this.reason,
  });

  factory Scrobble.fromJson(Map<String, dynamic> json) {
    return Scrobble(
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown',
      imageUrl: json['image_url'] ?? json['artist_image'],
      spotifyUrl: json['spotify_url'],
      reason: json['reason'],
    );
  }
}

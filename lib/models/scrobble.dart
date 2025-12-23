class Scrobble {
  final String title;
  final String artist;
  final String? imageUrl;

  Scrobble({required this.title, required this.artist, this.imageUrl});

  factory Scrobble.fromJson(Map<String, dynamic> json) {
    return Scrobble(
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown',
      imageUrl: json['image_url'],
    );
  }
}

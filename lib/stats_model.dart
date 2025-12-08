class TopSong {
  final String title;
  final String artist;
  final String? imageUrl;
  final int plays;

  TopSong({
    required this.title,
    required this.artist,
    this.imageUrl,
    required this.plays,
  });

  factory TopSong.fromJson(Map<String, dynamic> json) {
    return TopSong(
      title: json["title"],
      artist: json["artist"],
      imageUrl: json["img_url"],
      plays: json["plays"],
    );
  }
}

class TopArtist {
  final String artist;
  final int plays;

  TopArtist({required this.artist, required this.plays});

  factory TopArtist.fromJson(Map<String, dynamic> json) {
    return TopArtist(artist: json["artist"], plays: json["plays"]);
  }
}

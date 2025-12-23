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
  final String? artistImage;
  final int plays;

  TopArtist({required this.artist, this.artistImage, required this.plays});

  factory TopArtist.fromJson(Map<String, dynamic> json) {
    return TopArtist(
      artist: json["artist"],
      artistImage: json["artist_image"],
      plays: json["plays"],
    );
  }
}

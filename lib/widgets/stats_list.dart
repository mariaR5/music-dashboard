import 'package:flutter/material.dart';
import 'package:scrobbler/models/stats_model.dart';

class TopSongsList extends StatelessWidget {
  final List<TopSong> topSongs;
  const TopSongsList({super.key, required this.topSongs});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: topSongs.length,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final song = topSongs[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank
              SizedBox(
                width: 40,
                height: 70,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // Album Art
              ClipRRect(
                child: song.imageUrl != null
                    ? Image.network(
                        song.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: colors.primary,
                        child: Icon(Icons.music_note),
                      ),
              ),
              const SizedBox(width: 20),

              // Title and artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist,
                      style: TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // No. of plays
                    Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: colors.secondary,
                      ),
                      child: Text(
                        '${song.plays} plays',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TopArtistsList extends StatelessWidget {
  final List<TopArtist> topArtists;
  const TopArtistsList({super.key, required this.topArtists});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: topArtists.length,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final artist = topArtists[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 40,
                height: 70,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),

              // Artist image
              CircleAvatar(
                radius: 40,
                backgroundImage: artist.artistImage != null
                    ? NetworkImage(artist.artistImage!)
                    : null,
                child: artist.artistImage == null ? Icon(Icons.person) : null,
              ),
              const SizedBox(width: 20),
              // Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      artist.artist,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // No. of plays
                    Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Color(0xFF697565),
                      ),
                      child: Text(
                        '${artist.plays} plays',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

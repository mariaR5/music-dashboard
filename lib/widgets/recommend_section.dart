import 'package:flutter/material.dart';
import 'package:scrobbler/models/scrobble.dart';
import 'song_card.dart';

class RecommendSection extends StatelessWidget {
  final String title;
  final List<Scrobble> items;
  final Function(String)? onTap;
  final bool circularImage;
  final bool showItemReason;

  const RecommendSection({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.circularImage = false,
    this.showItemReason = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final song = items[index];
              final String validImage =
                  (song.imageUrl == null || song.imageUrl!.isEmpty)
                  ? 'https://placehold.co/150'
                  : song.imageUrl!;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SongCard(
                  imageUrl: validImage, // Fallback image
                  title: circularImage ? song.artist : song.title,
                  artist: circularImage ? '' : song.artist,
                  circularImage: circularImage,
                  onTap: () {
                    if (song.spotifyUrl != null && onTap != null) {
                      onTap!(song.spotifyUrl!);
                    }
                  },
                  reason: song.reason,
                  showItemReason: showItemReason,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'song_card.dart';

class RecommendSection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final Function(String) onTap;
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
        const SizedBox(height: 10),

        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final song = items[index];

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SongCard(
                  imageUrl: circularImage
                      ? song['artist_image']
                      : song['image_url'],
                  title: song['title'] ?? song['artist'],
                  artist: song['artist'],
                  circularImage: circularImage,
                  onTap: () {
                    if (song['spotify_url'] != null) {
                      onTap(song['spotify_url']);
                    }
                  },
                  reason: song['reason'],
                  showItemReason: showItemReason,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

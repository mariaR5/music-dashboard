import 'package:flutter/material.dart';

class ArtistCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;

  const ArtistCard({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Artist Image
          CircleAvatar(
            radius: 35,
            backgroundColor: colors.secondary,
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null ? Icon(Icons.person) : null,
          ),

          const SizedBox(width: 24),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

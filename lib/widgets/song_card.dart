import 'package:flutter/material.dart';

class SongCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String artist;
  final String? reason;
  final VoidCallback onTap;
  final bool circularImage;
  final bool showItemReason;

  const SongCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.artist,
    this.reason,
    required this.onTap,
    this.circularImage = false,
    this.showItemReason = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            circularImage
                ? CircleAvatar(
                    radius: 70,
                    child: ClipOval(
                      child: Image.network(
                        imageUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey,
                            child: Icon(Icons.music_note),
                          );
                        },
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey,
                          child: Icon(Icons.music_note),
                        );
                      },
                    ),
                  ),

            const SizedBox(height: 5),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 3),
            if (showItemReason && reason != null)
              Text(
                reason!,
                style: const TextStyle(fontSize: 8, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

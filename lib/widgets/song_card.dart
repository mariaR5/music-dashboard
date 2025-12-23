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
                    backgroundImage: NetworkImage(imageUrl),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
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

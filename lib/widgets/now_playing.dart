import 'package:flutter/material.dart';

class NowPlaying extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;

  const NowPlaying({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Album art, song name and artist
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 200,
                width: 200,
                color: const Color(0xFF697565),
                child: ClipRRect(
                  child: imageUrl != null
                      ? Image.network(imageUrl!, fit: BoxFit.cover)
                      : Icon(Icons.music_note),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                textAlign: TextAlign.center,
              ),
              Text(
                artist,
                style: TextStyle(fontWeight: FontWeight.w300, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

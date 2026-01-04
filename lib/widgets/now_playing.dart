import 'package:flutter/material.dart';
import 'package:scrobbler/widgets/audio_wave.dart';

class NowPlaying extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final bool isLoading;
  final bool isAnimating;

  const NowPlaying({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.isLoading = false,
    this.isAnimating = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Background audio wave
                  if (isAnimating)
                    Positioned(
                      width: 350,
                      child: AudioWave(
                        isAnimating: true,
                        height: 100,
                        color: Color(0xFF595959),
                      ),
                    ),

                  // Album art
                  Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    color: colors.surface,
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: 200,
                      width: 200,
                      child: ClipRRect(
                        child: isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: colors.secondary,
                                ),
                              )
                            : imageUrl != null
                            ? Image.network(imageUrl!, fit: BoxFit.cover)
                            : Icon(Icons.music_note, color: colors.secondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Song name and artist
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

import 'package:flutter/material.dart';

class InfoBullet extends StatelessWidget {
  final String title;
  final String text;

  const InfoBullet({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: colors.onSurface, fontSize: 14)),
      ],
    );
  }
}

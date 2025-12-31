import 'dart:math';
import 'package:flutter/material.dart';

class AudioWave extends StatefulWidget {
  final bool isAnimating;
  final double height;
  final Color color;

  const AudioWave({
    super.key,
    required this.isAnimating,
    this.height = 60,
    this.color = Colors.grey,
  });

  @override
  State<AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<AudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    }

    if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return CustomPaint(
            painter: WavePainter(
              color: widget.color,
              animationValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final double animationValue;

  WavePainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    const int barCount = 30;
    final double spacing = size.width / barCount;

    final double t = animationValue * 2 * pi;

    for (int i = 0; i < barCount; i++) {
      double randomHeight = 0.5 + 0.5 * sin(t + i * 300);
      double barHeight = size.height * randomHeight;

      double dy = (size.height - barHeight) / 2;
      double dx = i * spacing + (spacing / 2);

      canvas.drawLine(Offset(dx, dy), Offset(dx, dy + barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

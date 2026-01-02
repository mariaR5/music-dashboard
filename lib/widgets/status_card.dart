import 'dart:async';

import 'package:flutter/material.dart';

class StatusCard extends StatefulWidget {
  final bool isServiceRunning;
  final String currentPackage;

  const StatusCard({
    super.key,
    required this.isServiceRunning,
    required this.currentPackage,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  int _msgIndex = 0;
  Timer? _timer;

  Map<String, String> appNameMap = {
    'com.spotify.music': 'Spotify',
    'com.google.android.apps.youtube.music': 'YouTube Music',
    'com.soundcloud.android': 'SoundCloud',
    'com.apple.android.music': 'Apple Music',
    'com.aspiro.tidal': 'TIDAL',
    'deezer.android.app': 'Deezer',
    'com.maxmpz.audioplayer': 'Poweramp',
    'com.samsung.android.app.music': 'Samsung Music',
    'com.sec.android.app.music': 'Samsung Music',
    'com.miui.player': 'Mi Music',
    'com.oppo.music': 'OPPO Music',
    'com.oneplus.music': 'OnePlus Music',
    'com.lge.music': 'LG Music',
    'com.sony.walkman.music': 'Sony Walkman',
  };

  void initState() {
    super.initState();

    // Timer to change index (0 and 1) every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _msgIndex = (_msgIndex + 1) % 2;
        });
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    String textToShow;
    Key key;

    if (!widget.isServiceRunning) {
      textToShow = 'Service Stopped';
      key = const ValueKey('stopped');
    } else if (_msgIndex == 0) {
      textToShow = 'Service Running';
      key = const ValueKey('running');
    } else {
      final packageName = appNameMap[widget.currentPackage];
      textToShow = widget.currentPackage.isEmpty || packageName == null
          ? "Waiting for music..."
          : "Listening on $packageName";
      key = const ValueKey('package');
    }

    return Container(
      height: 50,
      width: 240,
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(820),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          layoutBuilder: (currentChild, previousChild) {
            return currentChild ?? const SizedBox.shrink();
          },
          child: Text(
            textToShow,
            key: key,
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

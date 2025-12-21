import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color color;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    required this.isMe,
    required this.color,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Set source immediately to fetch duration metadata
    _player
        .setSourceUrl(widget.url)
        .then((_) {
          // Optional: You could verify duration here if needed
        })
        .catchError((e) {
          debugPrint('Error setting audio source: $e');
        });

    _initAudio();
  }

  Future<void> _initAudio() async {
    _playerStateChangeSubscription = _player.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _playerState = state);
    });

    _durationSubscription = _player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _positionSubscription = _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    _playerCompleteSubscription = _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : Colors.black87;
    // Slider active/inactive colors
    final activeColor = widget.isMe
        ? Colors.white
        : Theme.of(context).primaryColor;
    final inactiveColor = widget.isMe ? Colors.white54 : Colors.grey[400];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      width: 260, // Fixed width for consistent look
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: textColor,
              size: 32,
            ),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: activeColor,
                    inactiveTrackColor: inactiveColor,
                    thumbColor: activeColor,
                    overlayColor: activeColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: (_position.inMilliseconds / 1000).clamp(
                      0.0,
                      (_duration.inMilliseconds / 1000) + 0.1,
                    ), // clamp to avoid errors
                    min: 0,
                    max: (_duration.inMilliseconds > 0)
                        ? (_duration.inMilliseconds / 1000)
                        : 1.0,
                    onChanged: (v) async {
                      final pos = Duration(milliseconds: (v * 1000).round());
                      await _player.seek(pos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

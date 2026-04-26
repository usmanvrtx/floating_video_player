import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/floating_state.dart';
import 'widgets/custom_player_controls.dart';

/// The core video-player widget.
///
/// Handles initialisation, URL changes, playback-speed changes, and the
/// optional drag-down gesture (used in landscape mode to exit full-screen).
class PlayerView extends StatefulWidget {
  final String? videoUrl;
  final PlayingContentType playingContentType;
  final bool autoPlay;
  final double playbackSpeed;
  final ValueNotifier<FloatingState> floatingState;
  final VoidCallback? onDragDownThresholdReached;
  final bool enableDragDownGesture;
  final VoidCallback? onArrowDownPressed;
  final VoidCallback? onFullscreenPressed;
  final VoidCallback? onSettingsPressed;

  const PlayerView({
    required this.floatingState,
    this.playingContentType = PlayingContentType.video,
    this.videoUrl,
    this.autoPlay = true,
    this.playbackSpeed = 1.0,
    this.onDragDownThresholdReached,
    this.enableDragDownGesture = false,
    this.onArrowDownPressed,
    this.onFullscreenPressed,
    this.onSettingsPressed,
    super.key,
  });

  @override
  State<PlayerView> createState() => PlayerViewState();
}

class PlayerViewState extends State<PlayerView> {
  static const double _dragDownThreshold = 100.0;
  static const Color _kPrimary = Color(0xFF4285F4);

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  double? _dragDownStartY;
  double _dragDownTranslateY = 0.0;
  bool _didReachDragDownThreshold = false;
  bool _shouldRestoreState = false;
  bool _wasPlaying = false;
  Duration _currentPosition = Duration.zero;
  bool _isInitializing = false;

  Duration _persistentPosition = Duration.zero;
  bool _persistentWasPlaying = false;

  /// Exposes the underlying [VideoPlayerController] for external consumers
  /// (e.g., the mini-player collapsed controls).
  VideoPlayerController? get videoPlayerController => _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant PlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final contentTypeChanged =
        widget.playingContentType != oldWidget.playingContentType;

    if (widget.videoUrl != oldWidget.videoUrl) {
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized) {
        _persistentPosition = _videoPlayerController!.value.position;
        _persistentWasPlaying = _videoPlayerController!.value.isPlaying;
      }

      if (contentTypeChanged) {
        _persistentPosition = Duration.zero;
        _persistentWasPlaying = false;
      }

      if (!contentTypeChanged) {
        _wasPlaying = _persistentWasPlaying;
        _currentPosition = _persistentPosition;
        _shouldRestoreState = true;
      } else {
        _wasPlaying = false;
        _currentPosition = Duration.zero;
        _shouldRestoreState = false;
      }
      _disposeControllers();
      _initializePlayer();
    } else if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      _videoPlayerController?.setPlaybackSpeed(widget.playbackSpeed);
    }
  }

  Future<void> _initializePlayer() async {
    if (widget.videoUrl == null) return;

    setState(() => _isInitializing = true);

    try {
      if (widget.videoUrl!.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(
          File(widget.videoUrl!),
        );
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.autoPlay || _wasPlaying,
        looping: false,
        allowedScreenSleep: false,
        customControls: CustomPlayerControls(
          controller: _videoPlayerController!,
          overlayState: widget.floatingState,
          onPlayPressed: () {
            if (_videoPlayerController!.value.isPlaying) {
              _videoPlayerController!.pause();
            } else {
              _videoPlayerController!.play();
            }
          },
          onArrowDownPressed: widget.onArrowDownPressed ?? () {},
          onFullscreenPressed: widget.onFullscreenPressed ?? () {},
          onSettingsPressed: widget.onSettingsPressed ?? () {},
        ),
      );

      await _videoPlayerController!.setPlaybackSpeed(widget.playbackSpeed);

      if (!_shouldRestoreState && widget.autoPlay) {
        await _videoPlayerController!.play();
      }

      if (_shouldRestoreState) {
        if (_currentPosition != Duration.zero) {
          await _videoPlayerController!.seekTo(_currentPosition);
        }
        if (_wasPlaying) {
          await _videoPlayerController!.play();
        }
        _shouldRestoreState = false;
      }
    } catch (_) {
      // Initialisation failed – the loading indicator remains visible.
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _chewieController == null) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        if (widget.enableDragDownGesture) {
          _dragDownStartY = details.globalPosition.dy;
          _dragDownTranslateY = 0.0;
          _didReachDragDownThreshold = false;
        }
      },
      onPanUpdate: (details) {
        if (widget.enableDragDownGesture && _dragDownStartY != null) {
          final dragDownDistance =
              (details.globalPosition.dy - _dragDownStartY!).clamp(
                0.0,
                _dragDownThreshold,
              );

          if (_dragDownTranslateY != dragDownDistance) {
            setState(() {
              _dragDownTranslateY = dragDownDistance;
            });
          }

          _didReachDragDownThreshold = dragDownDistance >= _dragDownThreshold;
        }
      },
      onPanEnd: (_) {
        if (widget.enableDragDownGesture) {
          final shouldTrigger = _didReachDragDownThreshold;

          if (shouldTrigger) {
            widget.onDragDownThresholdReached?.call();
            if (!mounted) return;
          }

          if (_dragDownTranslateY != 0.0) {
            setState(() {
              _dragDownTranslateY = 0.0;
            });
          }

          _dragDownStartY = null;
          _didReachDragDownThreshold = false;
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _dragDownTranslateY),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        builder: (context, animatedY, child) {
          return Transform.translate(
            offset: Offset(0, animatedY),
            child: child,
          );
        },
        child: Stack(
          children: [
            Chewie(controller: _chewieController!),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _videoPlayerController!,
              builder: (context, value, _) {
                if (!value.isBuffering) return const SizedBox.shrink();
                return const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

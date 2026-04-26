import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controller/floating_view_controller.dart';
import '../gestures/player_animation_mixin.dart';
import '../models/floating_state.dart';
import '../models/video_quality.dart';
import 'player_view.dart';
import 'widgets/circle_button.dart';

/// Callback that supplies an [AnimationController] the content widget can
/// drive for an entrance slide-in animation when first shown.
typedef SlideAnimationCallback = void Function(AnimationController controller);

/// The main floating player view.
///
/// Place this inside a [FloatingViewProvider] and open it through
/// [FloatingViewController.open]:
///
/// ```dart
/// context.floatingController.open(context, (key) => FloatingPlayerView(
///   key: key,
///   videoUrl: 'https://...',
///   contentBuilder: (ctx, onSlide) => MyArticleContent(onSlide: onSlide),
/// ));
/// ```
///
/// To embed the player directly in the widget tree (non-overlay mode), simply
/// place [FloatingPlayerView] as a child of any widget.
class FloatingPlayerView extends StatefulWidget {
  /// URL of the video to play. If `null` a loading indicator is shown.
  final String? videoUrl;

  /// Optional quality selection.  If omitted the [videoUrl] is used directly.
  final VideoQuality? quality;

  /// Which kind of content is currently playing (affects position restoration).
  final PlayingContentType playingContentType;

  /// Whether to start playback automatically when the player is ready.
  final bool autoPlay;

  /// Initial playback speed multiplier.
  final double playbackSpeed;

  /// Called when the user presses the ↓ arrow button.
  final VoidCallback? onArrowDownPressed;

  /// Called when the user presses the fullscreen toggle button.
  final VoidCallback? onFullscreenPressed;

  /// Called when the user presses the settings button.
  final VoidCallback? onSettingsPressed;

  /// Builder for the scrollable content shown below the video in portrait mode.
  ///
  /// Receives a [SlideAnimationCallback] that the content widget can call with
  /// its own [AnimationController] to trigger the entrance slide animation.
  final Widget Function(
    BuildContext context,
    SlideAnimationCallback onSlideAnimation,
  )?
  contentBuilder;

  /// Widget shown while the player is in a loading/error state.
  /// Defaults to a simple black scaffold with a progress indicator.
  final Widget? loadingWidget;

  /// Height reserved for the host app's bottom navigation bar.
  ///
  /// Used when calculating mini-player snap positions.
  /// Defaults to [kBottomNavigationBarHeight] (56 dp).
  final double bottomNavBarHeight;

  const FloatingPlayerView({
    this.videoUrl,
    this.quality,
    this.playingContentType = PlayingContentType.video,
    this.autoPlay = true,
    this.playbackSpeed = 1.0,
    this.onArrowDownPressed,
    this.onFullscreenPressed,
    this.onSettingsPressed,
    this.contentBuilder,
    this.loadingWidget,
    this.bottomNavBarHeight = kBottomNavigationBarHeight,
    super.key,
  });

  @override
  State<FloatingPlayerView> createState() => FloatingPlayerViewState();
}

class FloatingPlayerViewState extends State<FloatingPlayerView>
    with TickerProviderStateMixin, PlayerAnimationMixin {
  bool _showSlideAnimation = false;

  double get _currentPlaybackSpeed => widget.playbackSpeed;

  bool get _shouldAutoPlayPlayer {
    final controller = playerKey.currentState?.videoPlayerController;
    if (controller == null || !controller.value.isInitialized) {
      return true;
    }
    return controller.value.isPlaying;
  }

  @override
  void initState() {
    super.initState();
    _showSlideAnimation = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initFloatingController(context);
    setCollapseOffsets(MediaQuery.of(context).size);
  }

  final GlobalKey<PlayerViewState> playerKey = GlobalKey<PlayerViewState>();

  // ── Slide animation for bottom content ───────────────────────────────────

  void _slideAnimation(AnimationController controller) {
    if (_showSlideAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.forward().then((_) => _showSlideAnimation = false);
      });
    } else {
      controller.value = 1;
    }
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  void _onSettingsPressed() {
    widget.onSettingsPressed?.call();
  }

  void _onFullscreenPressed() {
    if (context.floatingController.floatingState.value ==
        FloatingState.landscaped) {
      context.floatingController.closeLandscapeVideo();
      return;
    }
    if (context.floatingController.floatingState.value ==
        FloatingState.expanded) {
      context.floatingController.openLandscapeVideo();
      return;
    }
  }

  void _onArrowDownPressed() {
    if (context.floatingController.floatingState.value !=
        FloatingState.landscaped) {
      c.collapse();
      return;
    } else {
      context.floatingController.closeLandscapeVideo();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: ValueListenableBuilder<FloatingState>(
        valueListenable: c.floatingState,
        child: widget.contentBuilder != null
            ? Expanded(
                child: AnimatedBuilder(
                  animation: animationController,
                  builder: (context, child) {
                    final offset = boundedOffset(screenSize);
                    return Transform.translate(
                      offset: Offset(0, offset.dy),
                      child: Opacity(opacity: contentAlpha / 255, child: child),
                    );
                  },
                  child: RepaintBoundary(
                    child: widget.contentBuilder!(context, _slideAnimation),
                  ),
                ),
              )
            : null,
        builder: (context, floatingState, bottomContent) {
          final screenIsLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;

          if (floatingState == FloatingState.landscaped || screenIsLandscape) {
            return Material(
              color: Colors.black,
              child: PlayerView(
                key: playerKey,
                videoUrl: widget.videoUrl,
                quality: widget.quality,
                playingContentType: widget.playingContentType,
                autoPlay: _shouldAutoPlayPlayer,
                playbackSpeed: _currentPlaybackSpeed,
                floatingState: context.floatingController.floatingState,
                enableDragDownGesture: true,
                onArrowDownPressed:
                    widget.onArrowDownPressed ?? _onArrowDownPressed,
                onFullscreenPressed: _onFullscreenPressed,
                onSettingsPressed: _onSettingsPressed,
                onDragDownThresholdReached: () {
                  context.floatingController.closeLandscapeVideo();
                },
              ),
            );
          }

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: animationController,
                  builder: (context, child) {
                    final offset = boundedOffset(screenSize);

                    return Transform.translate(
                      offset: offset,
                      filterQuality: FilterQuality.high,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topLeft,
                        filterQuality: FilterQuality.high,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadius),
                          clipBehavior: Clip.hardEdge,
                          child: AspectRatio(
                            aspectRatio: currentAspectRatio,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: floatingState == FloatingState.collapsed
                      ? GestureDetector(
                          onTap: enterExpandedView,
                          onPanStart: onCollapsedDragStart,
                          onPanUpdate: onCollapsedDragUpdate,
                          onPanEnd: onCollapsedDragEnd,
                          child: _topChild(),
                        )
                      : GestureDetector(
                          onVerticalDragStart: onDragStart,
                          onVerticalDragUpdate: onDragUpdate,
                          onVerticalDragEnd: onDragEnd,
                          child: _topChild(),
                        ),
                ),
                if (bottomContent != null && !isCollapsed) bottomContent,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topChild() {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.black)),
        AbsorbPointer(
          absorbing: isCollapsed,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              final playerHeight = width / collapsedAspectRatio;
              final finalHeight = playerHeight > height ? height : playerHeight;

              return SizedBox(
                width: width,
                height: finalHeight,
                child: PlayerView(
                  key: playerKey,
                  videoUrl: widget.videoUrl,
                  quality: widget.quality,
                  playingContentType: widget.playingContentType,
                  autoPlay: _shouldAutoPlayPlayer,
                  playbackSpeed: _currentPlaybackSpeed,
                  floatingState: context.floatingController.floatingState,
                  onArrowDownPressed:
                      widget.onArrowDownPressed ?? _onArrowDownPressed,
                  onFullscreenPressed: _onFullscreenPressed,
                  onSettingsPressed: _onSettingsPressed,
                ),
              );
            },
          ),
        ),
        if (isCollapsed) ..._collapsedControls(),
      ],
    );
  }

  List<Widget> _collapsedControls() {
    final controller = playerKey.currentState?.videoPlayerController;
    if (controller == null) return [];

    return [
      Positioned(
        top: 16,
        left: 16,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final isPlaying = value.isPlaying;
            return CircleButton(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              onPressed: () {
                if (isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              },
            );
          },
        ),
      ),
      Positioned(
        top: 16,
        right: 16,
        child: CircleButton(
          icon: Icons.close,
          onPressed: context.floatingController.close,
        ),
      ),
    ];
  }

  @override
  void dispose() {
    disposeAnimationResources();
    super.dispose();
  }
}

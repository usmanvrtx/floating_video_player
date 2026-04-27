import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controller/floating_view_controller.dart';
import '../gestures/player_animation_mixin.dart';
import '../models/floating_state.dart';
import '../models/video_source.dart';
import 'player_view.dart';
import 'widgets/circle_button.dart';

class FloatingPlayerView extends StatefulWidget {
  final VideoSource? source;
  final bool autoPlay;
  final Widget Function()? contentBuilder;

  const FloatingPlayerView({
    this.source,
    this.autoPlay = true,
    this.contentBuilder,
    super.key,
  });

  @override
  State<FloatingPlayerView> createState() => FloatingPlayerViewState();
}

class FloatingPlayerViewState extends State<FloatingPlayerView>
    with TickerProviderStateMixin, PlayerAnimationMixin {
  bool _showSlideAnimation = false;
  bool _collapseAnimationComplete = false;

  bool get _shouldAutoPlayPlayer {
    final controller = _playerKey.currentState?.videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return true;
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

    // Trigger slide animation
    _slideAnimation();

    // Listen to animation controller to know when collapse completes
    animationController.addStatusListener(_onAnimationStatusChanged);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Animation completed - show controls only if still in collapsed state
      if (mounted && isCollapsed) {
        setState(() => _collapseAnimationComplete = true);
      } else if (mounted && _collapseAnimationComplete) {
        // If not collapsed anymore, hide the controls
        setState(() => _collapseAnimationComplete = false);
      }
    } else if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      // Animation started - always hide controls during animation
      if (mounted && _collapseAnimationComplete) {
        setState(() => _collapseAnimationComplete = false);
      }
    }
  }

  final GlobalKey<PlayerViewState> _playerKey = GlobalKey<PlayerViewState>();

  /// The underlying [VideoPlayerController] of the active video.
  ///
  /// Returns `null` while the video is still initialising.
  VideoPlayerController? get videoPlayerController =>
      _playerKey.currentState?.videoPlayerController;

  void _slideAnimation() {
    if (_showSlideAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        animationController.forward().then((_) => _showSlideAnimation = false);
      });
    } else {
      animationController.value = 1;
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
                    child: widget.contentBuilder!(),
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
                key: _playerKey,
                source: widget.source,
                autoPlay: _shouldAutoPlayPlayer,
                floatingState: context.floatingController.floatingState,
                enableDragDownGesture: true,
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
                  key: _playerKey,
                  source: widget.source,
                  autoPlay: _shouldAutoPlayPlayer,
                  floatingState: context.floatingController.floatingState,
                ),
              );
            },
          ),
        ),
        if (isCollapsed && _collapseAnimationComplete) ..._collapsedControls(),
      ],
    );
  }

  List<Widget> _collapsedControls() {
    final controller = _playerKey.currentState?.videoPlayerController;
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
    animationController.removeStatusListener(_onAnimationStatusChanged);
    disposeAnimationResources();
    super.dispose();
  }
}

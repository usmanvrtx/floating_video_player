import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controller/floating_view_controller.dart';
import '../gestures/player_animation_mixin.dart';
import '../models/floating_state.dart';
import 'player_view.dart';
import 'widgets/circle_button.dart';

typedef SlideAnimationCallback = void Function(AnimationController controller);

class FloatingPlayerView extends StatefulWidget {
  final String? videoUrl;
  final bool autoPlay;
  final VoidCallback? onArrowDownPressed;
  final VoidCallback? onFullscreenPressed;
  final VoidCallback? onSettingsPressed;
  final Widget Function(
    BuildContext context,
    SlideAnimationCallback onSlideAnimation,
  )?
  contentBuilder;

  const FloatingPlayerView({
    this.videoUrl,
    this.autoPlay = true,
    this.onArrowDownPressed,
    this.onFullscreenPressed,
    this.onSettingsPressed,
    this.contentBuilder,
    super.key,
  });

  @override
  State<FloatingPlayerView> createState() => FloatingPlayerViewState();
}

class FloatingPlayerViewState extends State<FloatingPlayerView>
    with TickerProviderStateMixin, PlayerAnimationMixin {
  bool _showSlideAnimation = false;

  bool get _shouldAutoPlayPlayer {
    final controller = playerKey.currentState?.videoPlayerController;
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
  }

  final GlobalKey<PlayerViewState> playerKey = GlobalKey<PlayerViewState>();

  void _slideAnimation(AnimationController controller) {
    if (_showSlideAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.forward().then((_) => _showSlideAnimation = false);
      });
    } else {
      controller.value = 1;
    }
  }

  void _onFullscreenPressed() {
    final state = context.floatingController.floatingState.value;
    if (state == FloatingState.landscaped) {
      context.floatingController.closeLandscapeVideo();
    } else if (state == FloatingState.expanded) {
      context.floatingController.openLandscapeVideo();
    }
  }

  void _onArrowDownPressed() {
    if (context.floatingController.floatingState.value ==
        FloatingState.landscaped) {
      context.floatingController.closeLandscapeVideo();
    } else {
      c.collapse();
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
                autoPlay: _shouldAutoPlayPlayer,
                floatingState: context.floatingController.floatingState,
                enableDragDownGesture: true,
                onArrowDownPressed:
                    widget.onArrowDownPressed ?? _onArrowDownPressed,
                onFullscreenPressed: _onFullscreenPressed,
                onSettingsPressed: widget.onSettingsPressed,
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
                  autoPlay: _shouldAutoPlayPlayer,
                  floatingState: context.floatingController.floatingState,
                  onArrowDownPressed:
                      widget.onArrowDownPressed ?? _onArrowDownPressed,
                  onFullscreenPressed: _onFullscreenPressed,
                  onSettingsPressed: widget.onSettingsPressed,
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

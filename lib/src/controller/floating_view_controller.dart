import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/floating_state.dart';
import '../player/floating_player_view.dart';

/// Builder for custom player controls.
///
/// If you want to use custom controls instead of the default [PlayerControls],
/// provide a builder that creates your control widget with the given parameters.
typedef PlayerControlsBuilder =
    Widget Function(
  VideoPlayerController videoController,
  ValueNotifier<FloatingState> floatingState,
    );

// ---------------------------------------------------------------------------
// ViewportInsets
// ---------------------------------------------------------------------------

/// Extra insets that shrink the usable area for the mini-player.
///
/// Set values for any persistent UI chrome that overlaps the screen:
/// - [bottom] — bottom navigation bar, media player bar, etc.
/// - [top]    — persistent header/banner below the app bar.
/// - [left] / [right] — side rails or drawers that are always visible.
///
/// All values default to `0`. System insets (status bar, gesture nav bar) are
/// already accounted for automatically via [MediaQuery.padding].
///
/// Example — app has a 56 dp bottom nav bar:
/// ```dart
/// controller.updateConstraints(
///   const ViewportInsets(bottom: kBottomNavigationBarHeight),
/// );
/// ```
class ViewportInsets {
  final double top;
  final double bottom;
  final double left;
  final double right;

  const ViewportInsets({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });

  const ViewportInsets.zero() : top = 0, bottom = 0, left = 0, right = 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportInsets &&
          top == other.top &&
          bottom == other.bottom &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode => Object.hash(top, bottom, left, right);
}

// ---------------------------------------------------------------------------
// FloatingViewController
// ---------------------------------------------------------------------------

/// Controls the lifecycle and orientation of the floating video player.
///
/// Obtain an instance from [FloatingViewProvider] and interact with it via the
/// [FloatingViewX] extension:
///
/// ```dart
/// context.floatingController.open(context, (key) => FloatingPlayerView(key: key, ...));
/// ```
class FloatingViewController {
  OverlayEntry? _entry;
  GlobalKey<FloatingPlayerViewState>? floatingViewKey;
  Future<void>? _orientationTransition;

  final ValueNotifier<FloatingState> floatingState = ValueNotifier(
    FloatingState.closed,
  );

  // ── Static layout configuration (set once at construction) ───────────────

  /// Scale of the mini-player relative to screen width. Defaults to `0.45`.
  final double collapsedScale;

  /// Aspect ratio used for the expanded (portrait) player. Defaults to `16/9`.
  final double expandedAspectRatio;

  /// Aspect ratio used for the mini-player. Defaults to `16/10`.
  final double collapsedAspectRatio;

  /// Corner radius of the mini-player. Defaults to `24`.
  final double collapsedRadius;

  /// Margin that keeps the mini-player away from screen edges.
  final EdgeInsets collapsedMargin;

  /// Progress fraction [0–1] at which a slow drag commits to collapsing.
  /// Defaults to `0.35`.
  final double snapDistanceFactor;

  /// Velocity threshold (in normalised units) above which a fling always
  /// collapses the player. Defaults to `1.5`.
  final double snapVelocityThreshold;

  // ── Live viewport constraints ─────────────────────────────────────────────

  /// Current extra insets that bound the mini-player's snap region.
  ///
  /// Read by [PlayerAnimationMixin] when calculating snap positions.
  /// Call [updateConstraints] to change this at runtime.
  ViewportInsets viewportInsets;

  // ── Custom controls ───────────────────────────────────────────────────────

  /// Whether to use custom controls instead of the default [PlayerControls].
  final bool useCustomControls;

  /// Builder for custom player controls.
  ///
  /// Only used if [useCustomControls] is `true`.
  /// Receives the video controller, floating state, and callback handlers.
  final PlayerControlsBuilder? customControlsBuilder;

  FloatingViewController({
    this.collapsedScale = 0.45,
    this.expandedAspectRatio = 16 / 9,
    this.collapsedAspectRatio = 16 / 10,
    this.collapsedRadius = 24.0,
    this.collapsedMargin = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 8.0,
    ),
    this.snapDistanceFactor = 0.35,
    this.snapVelocityThreshold = 1.5,
    ViewportInsets initialInsets = const ViewportInsets.zero(),
    this.useCustomControls = false,
    this.customControlsBuilder,
  }) : viewportInsets = initialInsets;

  // ── Runtime constraint update ─────────────────────────────────────────────

  /// Updates the viewport insets that bound the mini-player's snap region.
  ///
  /// Call this whenever persistent UI chrome is shown or hidden — e.g. when a
  /// bottom nav bar appears or the app switches to a fullscreen route.
  ///
  /// The mini-player position is immediately re-snapped if the player is
  /// currently in the collapsed state.
  ///
  /// ```dart
  /// // Bottom nav bar became visible:
  /// controller.updateConstraints(
  ///   const ViewportInsets(bottom: kBottomNavigationBarHeight),
  /// );
  ///
  /// // No persistent chrome:
  /// controller.updateConstraints(const ViewportInsets.zero());
  /// ```
  void updateConstraints(ViewportInsets insets) {
    if (viewportInsets == insets) return;
    viewportInsets = insets;
    floatingViewKey?.currentState?.reapplyConstraints();
  }

  /// Opens a new floating player overlay.
  ///
  /// [viewBuilder] receives the [GlobalKey] that must be assigned to the
  /// [FloatingPlayerView] so the controller can drive its state machine.
  ///
  /// Any previous overlay is automatically closed before the new one is shown.
  void open(
    BuildContext context,
    Widget Function(GlobalKey<FloatingPlayerViewState> key) viewBuilder,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();

    close();

    floatingViewKey = GlobalKey<FloatingPlayerViewState>();

    _entry = OverlayEntry(
      builder: (_) {
        return _FadeInWrapper(
          duration: const Duration(milliseconds: 350),
          child: viewBuilder(floatingViewKey!),
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    floatingState.value = FloatingState.expanded;
  }

  /// Transitions to full-screen landscape mode.
  Future<void> openLandscapeVideo() {
    if (floatingState.value == FloatingState.landscaped) {
      return _orientationTransition ?? Future.value();
    }

    return _runOrientationTransition(() async {
      floatingState.value = FloatingState.landscaped;
      await Future.wait([
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      ]);
    });
  }

  /// Returns from landscape mode to portrait expanded mode.
  Future<void> closeLandscapeVideo() {
    if (floatingState.value == FloatingState.expanded) {
      return _orientationTransition ?? Future.value();
    }

    return _runOrientationTransition(() async {
      floatingState.value = FloatingState.expanded;
      await Future.wait([
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]),
      ]);
    });
  }

  Future<void> _runOrientationTransition(Future<void> Function() transition) {
    if (_orientationTransition != null) {
      return _orientationTransition!;
    }

    final future = transition().whenComplete(() {
      _orientationTransition = null;
    });
    _orientationTransition = future;
    return future;
  }

  /// Closes and removes the floating overlay entirely.
  void close() {
    floatingViewKey?.currentState?.detachRouteFromContext();

    floatingState.value = FloatingState.closed;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    floatingViewKey = null;
  }

  /// Restores a collapsed mini-player to full expanded view.
  void expand() {
    floatingViewKey?.currentState?.enterExpandedView();
  }

  /// Collapses the expanded player to the mini-player corner.
  void collapse() {
    floatingViewKey?.currentState?.enterCollapsedView();
  }

  /// Plays the current video.
  void play() {
    floatingViewKey?.currentState?.playerKey.currentState?.videoPlayerController
        ?.play();
  }

  /// Pauses the current video. Delegates to the player state.
  void pause() {
    floatingViewKey?.currentState?.playerKey.currentState?.videoPlayerController
        ?.pause();
  }
}

// ---------------------------------------------------------------------------
// InheritedWidget provider
// ---------------------------------------------------------------------------

extension FloatingViewX on BuildContext {
  FloatingViewController get floatingController =>
      FloatingViewProvider.of(this);
}

class FloatingViewProvider extends InheritedWidget {
  final FloatingViewController controller;

  const FloatingViewProvider({
    required this.controller,
    required super.child,
    super.key,
  });

  static FloatingViewController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<FloatingViewProvider>();
    assert(provider != null, 'No FloatingViewProvider found in context');
    return provider!.controller;
  }

  @override
  bool updateShouldNotify(covariant FloatingViewProvider oldWidget) =>
      controller != oldWidget.controller;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// A lightweight fade-in wrapper used inside the overlay entry.
class _FadeInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FadeInWrapper({required this.child, required this.duration});

  @override
  State<_FadeInWrapper> createState() => __FadeInWrapperState();
}

class __FadeInWrapperState extends State<_FadeInWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

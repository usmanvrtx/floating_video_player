import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/floating_state.dart';
import '../player/floating_player_view.dart';

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

  // ── Convenience aliases matching the requested public API ─────────────────

  /// Alias for [expand].
  void restore() => expand();

  /// Alias for [collapse].
  void minimize() => collapse();

  /// Alias for [open] when used in an embedded/floating context.
  void openFloating(
    BuildContext context,
    Widget Function(GlobalKey<FloatingPlayerViewState> key) viewBuilder,
  ) => open(context, viewBuilder);

  /// Alias for [close].
  void closeFloating() => close();

  /// Plays the current video. Delegates to the player state.
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

/// A lightweight fade-in wrapper that replaces the animate_do FadeIn widget
/// inside the overlay entry so that animate_do is only required by the
/// playback-speed sheet.
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

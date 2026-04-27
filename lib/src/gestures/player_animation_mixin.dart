import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../controller/floating_view_controller.dart';
import '../models/floating_state.dart';
import '../overlay/overlay_stack_manager.dart';
import '../player/floating_player_view.dart';

// ---------------------------------------------------------------------------
// Package-level back-button handler
// ---------------------------------------------------------------------------

/// Default back-button handler for the floating player.
///
/// Closes open overlays first; otherwise drives the player state machine.
/// Returns `true` when the system should proceed with the native back action.
Future<bool> handleFloatingWillPop(BuildContext context) async {
  final overlayStack = OverlayStackManager();
  if (overlayStack.hasOverlays) {
    overlayStack.popTopOverlay();
    return false;
  }

  final floatingController = context.floatingController;
  final state = floatingController.floatingState.value;

  switch (state) {
    case FloatingState.collapsed:
      return true;
    case FloatingState.expanded:
      floatingController.collapse();
      return false;
    case FloatingState.landscaped:
      await floatingController.closeLandscapeVideo();
      return false;
    case FloatingState.closed:
      return true;
  }
}

// ---------------------------------------------------------------------------
// PlayerAnimationMixin
// ---------------------------------------------------------------------------

/// Mixin that wires up the full floating-player gesture and animation system.
///
/// Apply to any [State] that also mixes in [TickerProviderStateMixin].
/// Call [initFloatingController] from [didChangeDependencies] and
/// [setCollapseOffsets] whenever the screen size changes.
mixin PlayerAnimationMixin on State<FloatingPlayerView>
    implements TickerProvider {
  late final FloatingViewController c;
  bool _controllerInitialized = false;

  late final AnimationController animationController;

  ValueNotifier<bool> isAnimating = ValueNotifier(false);

  // Route management for overlay navigation.
  Route<dynamic>? _attachedRoute;
  bool _routeAttached = false;

  bool get isCollapsed => c.floatingState.value == FloatingState.collapsed;

  bool _isDragging = false;
  bool _isSwitchingToLandscape = false;
  double? _expandedDragStartY;
  bool _didCallExpandedDragUpThreshold = false;

  static const double _expandedDragUpThreshold = 56.0;

  double _collapseY = 0;
  double _collapseX = 0;

  // Collapsed free-drag state.
  Size? _screenSize;
  Offset? _collapsedPosition;
  Offset? _lastCollapsedPosition;
  late final AnimationController _snapX;
  late final AnimationController _snapY;

  // Drag tracking for precise pointer following.
  Offset? _dragStartGlobalPosition;
  Offset? _dragStartCollapsedPosition;

  // ── Layout configuration ─────────────────────────────────────────────────

  double collapsedScale = 0.45;
  double expandedAspectRatio = 16 / 9;
  double collapsedAspectRatio = 16 / 10;
  double collapsedRadius = 24.0;
  EdgeInsets collapsedMargin = const EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 8.0,
  );

  // ── Snap thresholds ───────────────────────────────────────────────────────

  double snapDistanceFactor = 0.35;
  double snapVelocityThreshold = 1.5;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(vsync: this);

    _snapX = AnimationController.unbounded(vsync: this);
    _snapY = AnimationController.unbounded(vsync: this);
    _snapX.addListener(_onSnapTick);
    _snapY.addListener(_onSnapTick);

    animationController.addStatusListener(_animationStatusListener);
    animationController.addListener(_animationListener);
  }

  void initFloatingController(BuildContext context) {
    if (_controllerInitialized) return;
    c = context.floatingController;
    _controllerInitialized = true;

    // Apply layout config from the controller.
    collapsedScale = c.collapsedScale;
    expandedAspectRatio = c.expandedAspectRatio;
    collapsedAspectRatio = c.collapsedAspectRatio;
    collapsedRadius = c.collapsedRadius;
    collapsedMargin = c.collapsedMargin;
    snapDistanceFactor = c.snapDistanceFactor;
    snapVelocityThreshold = c.snapVelocityThreshold;

    _initRouteManagement(context);
  }

  void _initRouteManagement(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.floatingState.value == FloatingState.expanded && !_routeAttached) {
        _attachRoute(context);
      }
    });
  }

  void _attachRoute(BuildContext context) {
    if (_routeAttached || _attachedRoute != null) return;

    try {
      final navigator = Navigator.of(context);
      _attachedRoute = PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        // ignore: deprecated_member_use
        pageBuilder: (_, __, ___) => WillPopScope(
          // ignore: deprecated_member_use
          onWillPop: () => handleFloatingWillPop(context),
          child: AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                color: Colors.black.withValues(
                  alpha: attachedRouteAlpha / 255.0,
                ),
              );
            },
          ),
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      );

      _routeAttached = true;
      debugPrint('[FloatingPlayer] Route: attached');

      navigator.push(_attachedRoute!);
    } catch (e) {
      _routeAttached = false;
      _attachedRoute = null;
    }
  }

  void _detachRoute(BuildContext context) {
    if (!_routeAttached || _attachedRoute == null) return;

    _routeAttached = false;
    final routeToRemove = _attachedRoute;
    _attachedRoute = null;
    debugPrint('[FloatingPlayer] Route: detached');

    try {
      final navigator = Navigator.of(context);
      if (navigator.canPop() && routeToRemove != null) {
        navigator.removeRoute(routeToRemove);
      }
    } catch (e) {
      // Silently fail if navigator is not available.
    }
  }

  /// Forces route detachment; called by [FloatingViewController.close].
  void detachRouteFromContext() {
    if (mounted) {
      _detachRoute(context);
    }
  }

  // ── Derived animation values ──────────────────────────────────────────────

  double get scale {
    final s = 1 - animationController.value * (1 - collapsedScale);
    return s.clamp(collapsedScale, 1.0);
  }

  double get currentAspectRatio {
    final t = animationController.value.clamp(0.0, 1.0);
    return expandedAspectRatio +
        (collapsedAspectRatio - expandedAspectRatio) * t;
  }

  EdgeInsets get margin {
    return EdgeInsets.lerp(
      EdgeInsets.zero,
      collapsedMargin,
      animationController.value,
    )!;
  }

  double get borderRadius {
    final t = animationController.value.clamp(0.0, 1.0);
    final fast = 1 - math.exp(-7 * t);
    final tail = math.pow(t, 4);
    final eased = fast * (1 - tail) + tail;
    return (collapsedRadius * eased).clamp(0.0, collapsedRadius);
  }

  /// Alpha [0–255] for the bottom content area.
  int get contentAlpha {
    const start = 0.0;
    const end = 0.2;
    final t = animationController.value.clamp(0.0, 1.0);
    double opacity;
    if (t <= start) {
      opacity = 1.0;
    } else if (t >= end) {
      opacity = 0.0;
    } else {
      final nt = (t - start) / (end - start);
      final eased = math.pow(nt, 0.8).toDouble();
      opacity = 1 - eased;
    }
    return (opacity * 255).round().clamp(0, 255);
  }

  /// Alpha [0–255] for the attached route background dimmer.
  int get attachedRouteAlpha {
    const start = 0.25;
    const end = 0.7;
    final t = animationController.value.clamp(0.0, 1.0);
    double opacity;
    if (t <= start) {
      opacity = 1.0;
    } else if (t >= end) {
      opacity = 0.0;
    } else {
      final nt = (t - start) / (end - start);
      final eased = math.pow(nt, 0.8).toDouble();
      opacity = 1 - eased;
    }
    return (opacity * 255).round().clamp(0, 255);
  }

  // ── Animation listeners ───────────────────────────────────────────────────

  void _animationListener() {
    isAnimating.value = animationController.isAnimating || _isDragging;
  }

  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (animationController.value == 1.0) {
        if (_routeAttached) {
          _detachRoute(context);
        }
        c.floatingState.value = FloatingState.collapsed;
        debugPrint('[FloatingPlayer] FloatingState: collapsed');

        _collapsedPosition ??=
            _lastCollapsedPosition ?? Offset(_collapseX, _collapseY);
        _lastCollapsedPosition = _collapsedPosition;
      } else if (animationController.value <= 0.01) {
        _attachRoute(context);
        c.floatingState.value = FloatingState.expanded;
        debugPrint('[FloatingPlayer] FloatingState: expanded');
        _lastCollapsedPosition ??= _collapsedPosition;
        _collapsedPosition = null;
      }
    }
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  double get _systemNavBarHeight => MediaQuery.of(context).padding.bottom;

  /// Extra bottom inset from app chrome (e.g. bottom nav bar).
  double get _extraBottomInset => c.viewportInsets.bottom;

  /// Extra top inset from app chrome (e.g. a persistent banner below the appbar).
  double get _extraTopInset => c.viewportInsets.top;

  /// Extra left/right insets from app chrome (e.g. side rails).
  double get _extraLeftInset => c.viewportInsets.left;
  double get _extraRightInset => c.viewportInsets.right;

  double get _totalBottomInset => _systemNavBarHeight + _extraBottomInset;

  void setCollapseOffsets(Size screenSize) {
    _screenSize = screenSize;

    final collapsedWidth = screenSize.width * collapsedScale;
    final collapsedHeight = collapsedWidth / collapsedAspectRatio;

    _collapseX =
        screenSize.width -
        collapsedWidth -
        collapsedMargin.right -
        _extraRightInset;
    _collapseY =
        screenSize.height -
        collapsedHeight -
        collapsedMargin.bottom -
        kToolbarHeight -
        _totalBottomInset;
  }

  /// Called by [FloatingViewController.updateConstraints] to re-snap the
  /// mini-player when viewport insets change at runtime.
  void reapplyConstraints() {
    if (_screenSize == null) return;
    setCollapseOffsets(_screenSize!);
    if (c.floatingState.value == FloatingState.collapsed &&
        _collapsedPosition != null) {
      final clamped = _clampCollapsedPosition(
        _collapsedPosition!,
        _screenSize!,
      );

      // Immediately move to the clamped position so there is no single-frame
      // flicker at the old (out-of-bounds) location.
      _collapsedPosition = clamped;
      _lastCollapsedPosition = clamped;

      // Sync the spring controllers so _snapToCorner animates FROM the already
      // clamped position, not from the previous out-of-bounds position.
      _snapX.stop();
      _snapY.stop();
      _snapX.value = clamped.dx;
      _snapY.value = clamped.dy;

      // Rebuild immediately so this frame renders the clamped position.
      setState(() {});

      // Then spring-animate to the nearest corner.
      _snapToCorner(Offset.zero);
    }
  }

  /// Clamps the animation offset to stay within visible bounds.
  Offset boundedOffset(Size screenSize) {
    final collapsed = _collapsedPosition;
    if (collapsed != null) {
      return Offset.lerp(Offset.zero, collapsed, animationController.value)!;
    }

    double safeMax(double max, double min) => math.max(max, min);

    final t = animationController.value;

    final baseW = screenSize.width;
    final childW = baseW * scale;
    final childH = childW / currentAspectRatio;

    final minX = margin.left;
    final minY = margin.top;

    final maxX = safeMax(
      screenSize.width - childW - margin.right - _extraRightInset,
      minX,
    );
    final maxY = safeMax(
      screenSize.height - childH - margin.bottom - _totalBottomInset,
      minY,
    );

    final x = (t * _collapseX).clamp(minX, maxX);
    final y = (t * _collapseY).clamp(minY, maxY);

    return Offset(x, y);
  }

  double _applyDragResistance(double value) {
    if (value < 0.0) {
      return value * 0.5;
    } else if (value > 1.0) {
      return 1.0 + (value - 1.0) * 0.5;
    }
    return value;
  }

  // ── Expanded-mode drag gestures ───────────────────────────────────────────

  void onDragStart(DragStartDetails d) {
    if (_isSwitchingToLandscape ||
        c.floatingState.value == FloatingState.landscaped) {
      return;
    }

    if (_collapsedPosition == null) {
      final fallback = _lastCollapsedPosition ?? Offset(_collapseX, _collapseY);
      _collapsedPosition = _screenSize != null
          ? _clampCollapsedPosition(fallback, _screenSize!)
          : fallback;
    }
    _expandedDragStartY = d.globalPosition.dy;
    _didCallExpandedDragUpThreshold = false;
    animationController.stop();
    _isDragging = true;
    isAnimating.value = true;
  }

  void onDragUpdate(DragUpdateDetails d) {
    if (_isSwitchingToLandscape ||
        c.floatingState.value == FloatingState.landscaped) {
      return;
    }

    if (!_didCallExpandedDragUpThreshold &&
        _expandedDragStartY != null &&
        c.floatingState.value == FloatingState.expanded) {
      final dragUpDistance = _expandedDragStartY! - d.globalPosition.dy;
      if (dragUpDistance >= _expandedDragUpThreshold) {
        _didCallExpandedDragUpThreshold = true;
        _openLandscapeFromGesture();
        return;
      }
    }

    final delta = d.delta.dy / _collapseY;
    final nextValue = animationController.value + delta;
    animationController.value = _applyDragResistance(nextValue).clamp(0.0, 1.0);
  }

  void onDragEnd(DragEndDetails details) {
    if (_isSwitchingToLandscape ||
        c.floatingState.value == FloatingState.landscaped) {
      _expandedDragStartY = null;
      _didCallExpandedDragUpThreshold = false;
      _isDragging = false;
      isAnimating.value = animationController.isAnimating;
      return;
    }

    _expandedDragStartY = null;
    _didCallExpandedDragUpThreshold = false;
    _isDragging = false;

    const double maxReleaseVelocity = 2.0;

    final double velocity = (details.velocity.pixelsPerSecond.dy / _collapseY)
        .clamp(-maxReleaseVelocity, maxReleaseVelocity);

    final double progress = animationController.value;

    final bool velocityIntent = velocity > snapVelocityThreshold;
    final bool distanceIntent = progress > snapDistanceFactor;

    final double target = (velocityIntent || distanceIntent) ? 1.0 : 0.0;

    if (target == 1.0 && c.floatingState.value != FloatingState.collapsed) {
      if (_routeAttached) {
        _detachRoute(context);
      }
      c.floatingState.value = FloatingState.collapsed;
      debugPrint('[FloatingPlayer] FloatingState: collapsed');
    }

    final SpringDescription spring = target == 1.0
        ? SpringDescription(
            mass: 2.0,
            stiffness: 360.0,
            damping: 1.85 * math.sqrt(1.6 * 360.0),
          )
        : SpringDescription(
            mass: 1.0,
            stiffness: 520.0,
            damping: 2.0 * math.sqrt(1.0 * 520.0),
          );

    animationController.animateWith(
      SpringSimulation(
        spring,
        animationController.value,
        target,
        velocity,
        snapToEnd: true,
      ),
    );
  }

  Future<void> _openLandscapeFromGesture() async {
    if (_isSwitchingToLandscape ||
        c.floatingState.value == FloatingState.landscaped) {
      return;
    }

    _isSwitchingToLandscape = true;
    _expandedDragStartY = null;
    _didCallExpandedDragUpThreshold = true;
    _isDragging = false;
    isAnimating.value = animationController.isAnimating;
    animationController.stop();

    try {
      await c.openLandscapeVideo();
    } finally {
      _isSwitchingToLandscape = false;
    }
  }

  // ── Collapsed-mode (mini-player) drag gestures ────────────────────────────

  void onCollapsedDragStart(DragStartDetails d) {
    _snapX.stop();
    _snapY.stop();
    _dragStartGlobalPosition = d.globalPosition;
    _dragStartCollapsedPosition = _collapsedPosition;
  }

  void onCollapsedDragUpdate(DragUpdateDetails d) {
    if (_dragStartGlobalPosition != null &&
        _dragStartCollapsedPosition != null &&
        _screenSize != null) {
      final dragDelta = d.globalPosition - _dragStartGlobalPosition!;
      _collapsedPosition = _clampCollapsedPosition(
        _dragStartCollapsedPosition! + dragDelta,
        _screenSize!,
      );
      setState(() {});
    }
  }

  void onCollapsedDragEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond;
    _dragStartGlobalPosition = null;
    _dragStartCollapsedPosition = null;
    _snapToCorner(velocity);
  }

  void _onSnapTick() {
    if (_collapsedPosition != null) {
      _collapsedPosition = Offset(_snapX.value, _snapY.value);
      setState(() {});
    }
  }

  Offset _clampCollapsedPosition(Offset pos, Size screenSize) {
    final childWidth = screenSize.width * collapsedScale;
    final childHeight = childWidth / collapsedAspectRatio;

    final minX = collapsedMargin.left + _extraLeftInset;
    final maxX =
        screenSize.width -
        childWidth -
        collapsedMargin.right -
        _extraRightInset;
    final minY = collapsedMargin.top + _extraTopInset;
    final maxY =
        screenSize.height -
        childHeight -
        collapsedMargin.bottom -
        kToolbarHeight -
        _totalBottomInset;

    return Offset(pos.dx.clamp(minX, maxX), pos.dy.clamp(minY, maxY));
  }

  Offset _nearestCorner(Size screenSize, {Offset velocity = Offset.zero}) {
    final childWidth = screenSize.width * collapsedScale;
    final childHeight = childWidth / collapsedAspectRatio;

    final left = collapsedMargin.left + _extraLeftInset;
    final right =
        screenSize.width -
        childWidth -
        collapsedMargin.right -
        _extraRightInset;
    final top = collapsedMargin.top + kToolbarHeight + _extraTopInset;
    final bottom =
        screenSize.height -
        childHeight -
        collapsedMargin.bottom -
        kToolbarHeight -
        _totalBottomInset;

    final corners = [
      Offset(left, top),
      Offset(right, top),
      Offset(left, bottom),
      Offset(right, bottom),
    ];

    const projectionTime = 0.20;
    final projected = _collapsedPosition! + velocity * projectionTime;

    Offset nearest = corners.first;
    double minDist = double.infinity;

    for (final corner in corners) {
      final dist = (projected - corner).distanceSquared;
      if (dist < minDist) {
        minDist = dist;
        nearest = corner;
      }
    }

    return nearest;
  }

  void _snapToCorner(Offset velocity) {
    if (_collapsedPosition == null || _screenSize == null) return;

    const double minSnapVelocity = 100.0;

    final from = _collapsedPosition!;
    final effectiveVelocity = velocity.distance >= minSnapVelocity
        ? velocity
        : Offset.zero;
    final to = _nearestCorner(_screenSize!, velocity: effectiveVelocity);

    _lastCollapsedPosition = to;

    if ((from - to).distanceSquared < 1.0) return;

    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 200.0,
      damping: 24.0,
    );

    final vx = velocity.dx.clamp(-1000.0, 1000.0);
    final vy = velocity.dy.clamp(-1000.0, 1000.0);

    _snapX.value = from.dx;
    _snapY.value = from.dy;

    _snapX.animateWith(
      SpringSimulation(spring, from.dx, to.dx, vx, snapToEnd: true),
    );
    _snapY.animateWith(
      SpringSimulation(spring, from.dy, to.dy, vy, snapToEnd: true),
    );
  }

  // ── Expand / Collapse programmatic transitions ────────────────────────────

  void enterExpandedView() {
    _snapX.stop();
    _snapY.stop();
    animationController.stop();

    if (_collapsedPosition != null) {
      _lastCollapsedPosition = _collapsedPosition;
    }

    _attachRoute(context);
    c.floatingState.value = FloatingState.expanded;

    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 320.0,
      damping: 2 * math.sqrt(1.0 * 320.0),
    );

    animationController.animateWith(
      SpringSimulation(
        spring,
        animationController.value,
        0.0,
        0.0,
        snapToEnd: true,
      ),
    );
  }

  void enterCollapsedView() {
    animationController.stop();

    _detachRoute(context);
    c.floatingState.value = FloatingState.collapsed;

    final fallback = _lastCollapsedPosition ?? Offset(_collapseX, _collapseY);
    _collapsedPosition = _screenSize != null
        ? _clampCollapsedPosition(fallback, _screenSize!)
        : fallback;

    final spring = SpringDescription(
      mass: 1.8,
      stiffness: 320.0,
      damping: 2 * math.sqrt(1.8 * 320),
    );

    animationController.animateWith(
      SpringSimulation(
        spring,
        animationController.value,
        1.0,
        0.0,
        snapToEnd: false,
      ),
    );
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  void disposeAnimationResources() {
    if (_routeAttached) {
      try {
        _detachRoute(context);
      } catch (_) {}
    }

    animationController.dispose();
    _snapX.dispose();
    _snapY.dispose();
    isAnimating.dispose();
  }
}

# floatube_player

[![pub.dev](https://img.shields.io/pub/v/floatube_player.svg)](https://pub.dev/packages/floatube_player)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter package that provides a **YouTube-style floating video player** — expand to full portrait view, collapse to a draggable mini-player in any corner, or go full-screen landscape. Built on top of [`video_player`](https://pub.dev/packages/video_player).

---

## Features

- **Expanded mode** — full-height portrait overlay with scrollable content below the player
- **Collapsed (mini-player) mode** — draggable, snap-to-corner picture-in-picture
- **Landscape mode** — immersive full-screen with drag-down-to-exit
- **Spring physics** — natural snap-to-corner animation using Flutter's physics engine
- **Viewport-aware** — respects bottom nav bars, side rails, and other persistent UI chrome via `ViewportInsets`
- **Custom controls** — replace the default controls with your own via `PlayerControlsBuilder`
- **Auto-hide controls** — controls fade out automatically after inactivity
- **Double-tap seek** — ±5 s seek with cumulative tap count indicator
- **Long-press fast-forward** — 2× speed while holding
- **Back-button integration** — collapses or exits appropriately

---

## Demo

### Expanded → Collapsed Transition
![Expand-collapse demo](https://raw.githubusercontent.com/usmanvrtx/floatube_player/main/doc/gifs/expand-collapse.gif)

### Mini-Player Drag & Snap
![Mini-player drag demo](https://raw.githubusercontent.com/usmanvrtx/floatube_player/main/doc/gifs/drag-snap.gif)

### Landscape Mode
![Landscape mode demo](https://raw.githubusercontent.com/usmanvrtx/floatube_player/main/doc/gifs/landscape.gif)

---

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  floatube_player: ^0.2.0
```

### Android

Add internet permission to `android/app/src/main/AndroidManifest.xml` for network videos:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

---

## Usage

### 1. Wrap your app with `FloatingViewProvider`

```dart
void main() {
  runApp(
    FloatingViewProvider(
      controller: FloatingViewController(
        // Optional: tell the player about persistent UI chrome
        initialInsets: const ViewportInsets(bottom: kBottomNavigationBarHeight),
      ),
      child: MaterialApp(home: MyHomeScreen()),
    ),
  );
}
```

### 2. Open the floating player

```dart
context.floatingController.open(
  context,
  (key) => FloatingPlayerView(
    key: key,
    source: VideoSource.network('https://example.com/video.mp4'),
    contentBuilder: () => MyScrollableContent(),
  ),
);
```

### 3. Control playback

Use the controller to manage player state:

```dart
final controller = context.floatingController;

// Collapse or expand
controller.collapse();   // Mini-player corner
controller.expand();     // Full portrait view

// Playback control
controller.play();       // Play
controller.pause();      // Pause
controller.seekTo(const Duration(seconds: 30));  // Seek to position

// Query player state
print(controller.isPlaying);        // bool
print(controller.currentPosition);  // Duration
print(controller.duration);         // Duration
print(controller.state);            // FloatingState

// Close and remove
controller.close();      // Remove overlay entirely
```

### 4. Handle persistent UI chrome

When a bottom nav bar, side rail, or other persistent UI appears/disappears, update the player's constraints. The mini-player snaps immediately to stay within the new bounds:

```dart
// Bottom nav bar appeared:
context.floatingController.updateConstraints(
  const ViewportInsets(bottom: kBottomNavigationBarHeight),
);

// Full-screen route, no chrome:
context.floatingController.updateConstraints(const ViewportInsets.zero());
```

### 5. Use an externally-managed VideoPlayerController

For advanced use cases, pass a pre-initialized controller to retain full control:

```dart
final myController = VideoPlayerController.networkUrl(
  Uri.parse('https://example.com/video.mp4'),
);
await myController.initialize();

context.floatingController.open(
  context,
  (key) => FloatingPlayerView(
    key: key,
    source: VideoSource.controller(myController),
  ),
);

// You retain full control — the player won't dispose it
myController.setPlaybackSpeed(1.5);
myController.seekTo(const Duration(minutes: 1));

// You're responsible for disposal
myController.dispose();
```

---

## Custom controls

Provide your own controls widget via `FloatingViewController`:

```dart
FloatingViewController(
  useCustomControls: true,
  customControlsBuilder: (videoController, overlayState, onPlayPressed) {
    return MyControls(
      controller: videoController,
      state: overlayState,
      onPlay: onPlayPressed,
    );
  },
)
```

---

## Architecture: Overlay-based system

### Important: The floating player is an overlay, not a widget tree

The floating player is **rendered in Flutter's overlay stack**, not as a child widget in your app's widget tree. This means:

- The player appears **above** all regular widgets, even if you don't nest it in your widget hierarchy
- It persists across navigation (push/pop) — the player stays visible when you navigate to other screens
- It renders independently, so it won't be affected by ancestor widget constraints, clipping, or state changes
- Closing the player removes it from the overlay entirely

This architecture enables the "picture-in-picture" behavior and seamless transitions between expanded, collapsed, and landscape states.

---

## `FloatingViewController` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `collapsedScale` | `double` | `0.45` | Mini-player width as a fraction of screen width |
| `expandedAspectRatio` | `double` | `16/9` | Aspect ratio in expanded portrait mode |
| `collapsedAspectRatio` | `double` | `16/10` | Aspect ratio of the mini-player |
| `collapsedRadius` | `double` | `24.0` | Corner radius of the mini-player |
| `collapsedMargin` | `EdgeInsets` | `12h, 8v` | Margin keeping the mini-player from screen edges |
| `snapDistanceFactor` | `double` | `0.35` | Drag fraction needed to commit a collapse |
| `snapVelocityThreshold` | `double` | `1.5` | Fling velocity that always collapses |
| `initialInsets` | `ViewportInsets` | `.zero()` | Initial viewport insets |
| `useCustomControls` | `bool` | `false` | Enable custom controls builder |
| `customControlsBuilder` | `PlayerControlsBuilder?` | `null` | Builder for custom controls widget |

---

## `FloatingViewController` API reference

### Methods

| Method | Description |
|---|---|
| `open(context, viewBuilder)` | Open the floating player overlay |
| `close()` | Close and remove the player |
| `expand()` | Restore collapsed mini-player to full view |
| `collapse()` | Collapse expanded player to mini-player corner |
| `play()` | Resume playback |
| `pause()` | Pause playback |
| `seekTo(Duration)` | Seek to a specific position |
| `openLandscapeVideo()` | Enter full-screen landscape mode |
| `closeLandscapeVideo()` | Exit landscape, return to portrait |
| `updateConstraints(ViewportInsets)` | Update viewport bounds for mini-player snap |

### Properties (read-only)

| Property | Type | Description |
|---|---|---|
| `state` | `FloatingState` | Current display state (closed, expanded, collapsed, or landscaped) |
| `floatingState` | `ValueNotifier<FloatingState>` | Listenable state notifier for reactive updates |
| `isPlaying` | `bool` | Whether the video is actively playing |
| `currentPosition` | `Duration` | Current playback position |
| `duration` | `Duration` | Total video duration |
| `videoPlayerController` | `VideoPlayerController?` | The underlying video controller (or null if not playing) |

---

## `FloatingPlayerView` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `VideoSource?` | `null` | Video source (network URL, file, asset, content URI, or external controller) |
| `autoPlay` | `bool` | `true` | Start playback automatically (ignored for external controllers) |
| `contentBuilder` | `Widget Function()?` | `null` | Scrollable content shown below the player in expanded portrait mode |

---

## `VideoSource` — video source types

The `VideoSource` sealed class provides multiple constructors for different video sources:

```dart
// Stream from HTTP/HTTPS URL
VideoSource.network('https://example.com/video.mp4')

// Load from local file
VideoSource.file(File('/path/to/video.mp4'))

// Load bundled Flutter asset
VideoSource.asset('assets/videos/demo.mp4')

// Android content URI (from media picker, etc.)
VideoSource.contentUri(Uri.parse('content://...'))

// Wrap an externally-managed VideoPlayerController
VideoSource.controller(myVideoPlayerController)
```

---

## Back-button handling

To properly handle the system back button, wrap your app's route with `WillPopScope` or `PopScope` and use `handleFloatingWillPop`:

```dart
WillPopScope(
  onWillPop: () => handleFloatingWillPop(context),
  child: MyScreen(),
)
```

The handler automatically:
- Closes any overlays first
- Collapses an expanded player
- Exits landscape mode
- Falls back to default back behavior when the player is closed

---

## License

MIT — see [LICENSE](LICENSE).

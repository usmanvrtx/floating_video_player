## 0.2.0

* **New: External VideoPlayerController support** — `VideoSource.controller()` factory lets you wrap and manage your own `VideoPlayerController` externally. The player won't dispose it when closed, letting you retain full control over playback.
* **New: Streamlined controller API** — added read-only getters for `state`, `isPlaying`, `currentPosition`, `duration`, and `videoPlayerController` via `context.floatingController`.
* **New: seekTo() method** — directly seek to any position via the controller.
* **Improved: Simplified internal methods** — `play()` and `pause()` now delegate through the single `videoPlayerController` getter.
* **Breaking: Cleaner public exports** — removed `PlayerView`, `PlayerViewState`, `PlayerAnimationMixin`, and `OverlayStackManager` from the barrel export. These are internal implementation details; use `FloatingViewController` and `FloatingPlayerView` as the public API.
* **Documentation: Comprehensive README updates** — added API reference tables, new usage examples for external controllers, and clearer guidance on viewport constraints and back-button handling.

## 0.1.2

* Fix demo GIFs to display properly on pub.dev by using GitHub raw URLs.

## 0.1.1

* Fix homepage URL to point to correct GitHub repository.

## 0.1.0

* Initial release.
* Expanded, collapsed (mini-player), and landscape floating player modes.
* Spring-physics snap-to-corner animation.
* `ViewportInsets` for runtime viewport constraint updates with immediate position re-snap.
* Default player controls: double-tap seek (±5 s), long-press 2× fast-forward, auto-hide.
* Custom controls support via `PlayerControlsBuilder`.
* `VideoSource` sealed class — supports network URL, local file, Flutter asset, and Android content URI.
* Back-button integration via `handleFloatingWillPop`.
* `OverlayStackManager` for managing layered overlay entries.

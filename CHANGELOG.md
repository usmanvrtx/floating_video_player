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

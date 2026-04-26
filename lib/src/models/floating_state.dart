/// Describes the current display state of the floating player.
enum FloatingState {
  /// Player is not rendered at all.
  closed,

  /// Player is minimised to a draggable mini-player in a corner of the screen.
  collapsed,

  /// Player is fully expanded in an overlay (portrait mode).
  expanded,

  /// Player is covering the entire screen in landscape orientation.
  landscaped,
}

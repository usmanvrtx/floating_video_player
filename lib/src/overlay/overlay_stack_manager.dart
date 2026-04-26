import 'package:flutter/material.dart';

/// Manages a stack of overlay entries identified by string keys.
///
/// Supports both bare overlays and modal overlays (with a dismissible barrier).
///
/// Usage:
/// ```dart
/// context.overlayStack.pushModalOverlay(key: 'my_key', context, (_) => MyWidget());
/// context.overlayStack.popOverlay('my_key');
/// ```
class OverlayStackManager {
  static final _instance = OverlayStackManager._();

  factory OverlayStackManager() => _instance;

  OverlayStackManager._();

  final List<OverlayEntry> _entries = [];
  final Map<String, List<OverlayEntry>> _keyToEntry = {};

  /// Inserts a new overlay on top of the current stack.
  String pushOverlay(
    BuildContext context,
    WidgetBuilder builder, {
    String? key,
  }) {
    final overlayKey = key ?? UniqueKey().toString();
    assert(
      !_keyToEntry.containsKey(overlayKey),
      'Overlay key must be unique: $overlayKey',
    );

    final entry = OverlayEntry(builder: (context) => builder(context));

    _entries.add(entry);
    _keyToEntry[overlayKey] = [entry];

    Overlay.of(context, rootOverlay: true).insert(entry);

    return overlayKey;
  }

  /// Inserts a modal overlay with a semi-transparent barrier.
  String pushModalOverlay(
    BuildContext context,
    WidgetBuilder builder, {
    String? key,
    Color barrierColor = Colors.black54,
    bool barrierDismissible = true,
  }) {
    final overlayKey = key ?? UniqueKey().toString();
    assert(
      !_keyToEntry.containsKey(overlayKey),
      'Overlay key must be unique: $overlayKey',
    );

    final barrierEntry = OverlayEntry(
      builder: (context) => barrierDismissible
          ? GestureDetector(
              onTap: () => popOverlay(overlayKey),
              child: Container(color: barrierColor),
            )
          : Container(color: barrierColor),
    );

    final contentEntry = OverlayEntry(builder: (context) => builder(context));

    final entries = [barrierEntry, contentEntry];
    _entries.addAll(entries);
    _keyToEntry[overlayKey] = entries;

    Overlay.of(context, rootOverlay: true).insertAll(entries);

    return overlayKey;
  }

  /// Closes the overlay registered under [key].
  void popOverlay(String key) {
    final entries = _keyToEntry.remove(key);
    if (entries != null) {
      for (final entry in entries) {
        entry.remove();
        _entries.remove(entry);
      }
    }
  }

  /// Closes the topmost overlay in the stack.
  void popTopOverlay() {
    if (_entries.isNotEmpty) {
      final lastEntry = _entries.last;
      String? keyToRemove;
      for (final entry in _keyToEntry.entries) {
        if (entry.value.contains(lastEntry)) {
          keyToRemove = entry.key;
          break;
        }
      }
      if (keyToRemove != null) {
        popOverlay(keyToRemove);
      }
    }
  }

  /// Removes all open overlays.
  void popAllOverlays() {
    for (final entry in _entries) {
      entry.remove();
    }
    _entries.clear();
    _keyToEntry.clear();
  }

  /// Returns `true` if an overlay with [key] is currently shown.
  bool isOverlayOpen(String key) => _keyToEntry.containsKey(key);

  /// Returns `true` if any overlay is currently shown.
  bool get hasOverlays => _entries.isNotEmpty;

  /// Number of currently open overlay groups.
  int get overlayCount => _keyToEntry.length;
}

/// Convenience extension for accessing [OverlayStackManager] from any
/// [BuildContext].
extension OverlayStackExtension on BuildContext {
  OverlayStackManager get overlayStack => OverlayStackManager();
}

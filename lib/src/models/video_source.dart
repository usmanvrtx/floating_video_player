import 'dart:io';

import 'package:video_player/video_player.dart';

/// Describes the source of a video to be played.
///
/// Use the named constructors to create a source:
/// - [VideoSource.network] — stream from an HTTP/HTTPS URL
/// - [VideoSource.file] — play a local [File]
/// - [VideoSource.asset] — play a bundled Flutter asset
/// - [VideoSource.contentUri] — play from an Android content URI
/// - [VideoSource.controller] — wrap an existing [VideoPlayerController]
sealed class VideoSource {
  const VideoSource._();

  /// A video streamed from an HTTP/HTTPS [url].
  const factory VideoSource.network(String url) = _NetworkSource;

  /// A video read from a local [file].
  const factory VideoSource.file(File file) = _FileSource;

  /// A video bundled as a Flutter asset at the given [path].
  const factory VideoSource.asset(String path) = _AssetSource;

  /// A video referenced by an Android content [uri]
  /// (e.g. from a media picker).
  const factory VideoSource.contentUri(Uri uri) = _ContentUriSource;

  /// Wraps an existing [VideoPlayerController] that is managed externally.
  ///
  /// The player will **not** dispose this controller when closed — the caller
  /// is responsible for its lifecycle. This lets you retain full control over
  /// playback, seek, speed, and other settings from outside the player.
  ///
  /// The controller may already be initialized before being passed in, or not.
  /// If not yet initialized, the player will call
  /// [VideoPlayerController.initialize] automatically.
  ///
  /// ```dart
  /// final myController = VideoPlayerController.networkUrl(Uri.parse('...'));
  /// await myController.initialize();
  ///
  /// context.floatingController.open(
  ///   context,
  ///   (key) => FloatingPlayerView(
  ///     key: key,
  ///     source: VideoSource.controller(myController),
  ///   ),
  /// );
  ///
  /// // Control playback from anywhere:
  /// myController.setPlaybackSpeed(1.5);
  /// myController.seekTo(const Duration(seconds: 30));
  /// ```
  factory VideoSource.controller(VideoPlayerController controller) =
      _ControllerSource;

  /// Whether this source wraps an externally-managed [VideoPlayerController].
  ///
  /// When `true`, the player will **not** call [VideoPlayerController.dispose]
  /// on close — lifecycle management remains the caller's responsibility.
  bool get isExternal => false;

  /// Creates or returns the [VideoPlayerController] for this source.
  VideoPlayerController toController() => switch (this) {
        _NetworkSource(:final url) =>
          VideoPlayerController.networkUrl(Uri.parse(url)),
        _FileSource(:final file) => VideoPlayerController.file(file),
        _AssetSource(:final path) => VideoPlayerController.asset(path),
        _ContentUriSource(:final uri) => VideoPlayerController.contentUri(uri),
        _ControllerSource(:final controller) => controller,
      };
}

final class _NetworkSource extends VideoSource {
  final String url;

  const _NetworkSource(this.url) : super._();

  @override
  bool operator ==(Object other) => other is _NetworkSource && other.url == url;

  @override
  int get hashCode => Object.hash('network', url);
}

final class _FileSource extends VideoSource {
  final File file;

  const _FileSource(this.file) : super._();

  @override
  bool operator ==(Object other) =>
      other is _FileSource && other.file.path == file.path;

  @override
  int get hashCode => Object.hash('file', file.path);
}

final class _AssetSource extends VideoSource {
  final String path;

  const _AssetSource(this.path) : super._();

  @override
  bool operator ==(Object other) => other is _AssetSource && other.path == path;

  @override
  int get hashCode => Object.hash('asset', path);
}

final class _ContentUriSource extends VideoSource {
  final Uri uri;

  const _ContentUriSource(this.uri) : super._();

  @override
  bool operator ==(Object other) =>
      other is _ContentUriSource && other.uri == uri;

  @override
  int get hashCode => Object.hash('contentUri', uri);
}

final class _ControllerSource extends VideoSource {
  final VideoPlayerController controller;

  // ignore: prefer_const_constructors_in_immutables
  _ControllerSource(this.controller) : super._();

  @override
  bool get isExternal => true;

  @override
  bool operator ==(Object other) =>
      other is _ControllerSource && identical(other.controller, controller);

  @override
  int get hashCode => Object.hash('controller', identityHashCode(controller));
}

import 'dart:io';

import 'package:video_player/video_player.dart';

/// Describes the source of a video to be played.
///
/// Use the named constructors to create a source:
/// - [VideoSource.network] — stream from an HTTP/HTTPS URL
/// - [VideoSource.file] — play a local [File]
/// - [VideoSource.asset] — play a bundled Flutter asset
/// - [VideoSource.contentUri] — play from an Android content URI
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

  /// Creates the appropriate [VideoPlayerController] for this source.
  VideoPlayerController toController() => switch (this) {
        _NetworkSource(:final url) =>
          VideoPlayerController.networkUrl(Uri.parse(url)),
        _FileSource(:final file) => VideoPlayerController.file(file),
        _AssetSource(:final path) => VideoPlayerController.asset(path),
        _ContentUriSource(:final uri) => VideoPlayerController.contentUri(uri),
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

/// Represents a single video quality option with its stream URL and resolution.
class VideoQuality {
  final String url;
  final int quality;

  const VideoQuality({required this.url, required this.quality});

  /// Human-readable label, e.g. "720p".
  String get label => '${quality}p';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoQuality &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          quality == other.quality;

  @override
  int get hashCode => url.hashCode ^ quality.hashCode;
}

/// Identifies which piece of content is currently loaded in the player.
enum PlayingContentType { video, animation, short }

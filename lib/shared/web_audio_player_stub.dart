// Stub file for non-web platforms.
// The real implementation is in web_audio_player_web.dart.

/// A no-op audio player stub for non-web platforms.
/// On web, the actual implementation uses HTMLAudioElement.
class WebAudioPlayer {
  final void Function(double progress)? onProgress;
  final void Function()? onComplete;

  WebAudioPlayer({this.onProgress, this.onComplete});

  bool get isPlaying => false;
  double get progress => 0.0;

  Future<void> play(String url) async {
    // No-op on native — audioplayers is used instead
  }

  void stop() {}
  void dispose() {}
}

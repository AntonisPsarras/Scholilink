import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// A simple audio player for web that uses the browser's HTMLAudioElement.
/// This is more reliable than audioplayers on Flutter web.
class WebAudioPlayer {
  web.HTMLAudioElement? _audio;
  Timer? _progressTimer;
  StreamSubscription? _loadedSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _errorSub;
  bool _isPlaying = false;
  double _progress = 0.0;
  double _duration = 0.0;

  final void Function(double progress)? onProgress;
  final void Function()? onComplete;

  WebAudioPlayer({this.onProgress, this.onComplete});

  bool get isPlaying => _isPlaying;
  double get progress => _progress;

  Future<void> play(String url) async {
    try {
      stop(); // Stop any existing playback
      _audio = web.HTMLAudioElement()..src = url;

      // Listen for when metadata is loaded (duration available)
      _loadedSub = _audio!.onLoadedMetadata.listen((_) {
        _duration = _audio!.duration;
      });

      // Listen for end
      _endedSub = _audio!.onEnded.listen((_) {
        _isPlaying = false;
        _progress = 0.0;
        _progressTimer?.cancel();
        onComplete?.call();
      });

      // Listen for errors
      _errorSub = _audio!.onError.listen((_) {
        debugPrint('WebAudioPlayer error loading: $url');
        _isPlaying = false;
        _progress = 0.0;
        _progressTimer?.cancel();
        onComplete?.call();
      });

      await _audio!.play().toDart;
      _isPlaying = true;
      if (!_audio!.duration.isNaN && _audio!.duration > 0) {
        _duration = _audio!.duration;
      }

      // Poll progress at a lower cadence to reduce CPU wakeups.
      _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (_audio != null && _duration > 0 && !_duration.isNaN) {
          _progress = (_audio!.currentTime / _duration).clamp(0.0, 1.0);
          onProgress?.call(_progress);
        }
      });
    } catch (e) {
      debugPrint('WebAudioPlayer play error: $e');
      _isPlaying = false;
    }
  }

  void stop() {
    _loadedSub?.cancel();
    _endedSub?.cancel();
    _errorSub?.cancel();
    _progressTimer?.cancel();
    if (_audio != null) {
      _audio!.pause();
      _audio!.currentTime = 0;
      _audio = null;
    }
    _isPlaying = false;
    _progress = 0.0;
  }

  void dispose() {
    stop();
  }
}

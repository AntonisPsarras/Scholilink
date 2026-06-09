import 'dart:async';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../theme/app_theme.dart';

/// A voice recorder widget that works on both web and native platforms.
/// Returns recorded audio as [Uint8List] bytes so callers can upload directly.
/// Also captures amplitude samples for waveform visualization.
class VoiceRecorderWidget extends StatefulWidget {
  final VoidCallback onCancel;

  /// Callback with the recorded audio bytes, duration in ms, and amplitude samples.
  final Future<void> Function(
    Uint8List bytes,
    int durationMs,
    List<double> amplitudes,
  )
  onSend;

  const VoiceRecorderWidget({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  static const int _waveformBarCount = 30;
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSending = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  Timer? _amplitudeTimer;
  final List<double> _amplitudeSamples = [];
  final List<double> _liveWaveformSamples = [];
  late AnimationController _pulseController;

  // Use ValueNotifier for amplitude data to avoid rebuilding entire widget.
  // Keep this list short and bounded to avoid O(n) growth per tick.
  final ValueNotifier<List<double>> _amplitudeNotifier = ValueNotifier(
    const [],
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _amplitudeNotifier.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!mounted) return;

    try {
      if (await _ensureMicrophonePermission()) {
        // Use WAV on web for broader compatibility, AAC on native
        if (kIsWeb) {
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              bitRate: 128000,
              sampleRate: 44100,
              numChannels: 1,
            ),
            path: '',
          );
        } else {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/voice_$timestamp.m4a';
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: path,
          );
        }

        if (!mounted) return;

        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        // Duration timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _recordingSeconds++);
        });

        // Sample less frequently to reduce wakeups and CPU use on low-end devices.
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 200), (
          timer,
        ) async {
          try {
            final amp = await _recorder.getAmplitude();
            if (mounted) {
              // amp.current is in dBFS (negative, -160 to 0)
              // Normalize to 0.0–1.0
              final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
              _amplitudeSamples.add(normalized);
              _liveWaveformSamples.add(normalized);
              if (_liveWaveformSamples.length > _waveformBarCount) {
                _liveWaveformSamples.removeAt(0);
              }
              _amplitudeNotifier.value = List<double>.from(
                _liveWaveformSamples,
              );
            }
          } catch (_) {}
        });
      } else {
        debugPrint('Voice recording: no permission');
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Voice recording start error: $e');
      widget.onCancel();
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    if (kIsWeb) {
      return _recorder.hasPermission();
    }

    final current = await Permission.microphone.status;
    if (current.isGranted) {
      return true;
    }

    final requested = await Permission.microphone.request();
    if (requested.isGranted) {
      return true;
    }

    if (!mounted) return false;

    final openSettings =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Microphone access required'),
              content: const Text(
                'Enable microphone permission in system settings to send voice messages.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open settings'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (openSettings) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _stopAndSend() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    _timer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        final Uint8List bytes;
        if (kIsWeb) {
          // On web, `path` is a blob URL (blob:http://...)
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            debugPrint(
              'Failed to fetch recorded audio blob: ${response.statusCode}',
            );
            widget.onCancel();
            return;
          }
        } else {
          bytes = await XFile(path).readAsBytes();
        }

        // Downsample amplitudes to ~30 bars for display
        final displayAmplitudes = _downsampleAmplitudes(
          _amplitudeSamples,
          _waveformBarCount,
        );

        await widget.onSend(bytes, _recordingSeconds * 1000, displayAmplitudes);
      } else {
        debugPrint('Voice recording: path is null or empty');
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Voice recording stop error: $e');
      widget.onCancel();
    }
  }

  List<double> _downsampleAmplitudes(List<double> samples, int targetCount) {
    if (samples.isEmpty) return List.filled(targetCount, 0.15);
    if (samples.length <= targetCount) {
      return [...samples, ...List.filled(targetCount - samples.length, 0.15)];
    }
    final result = <double>[];
    final chunkSize = samples.length / targetCount;
    for (int i = 0; i < targetCount; i++) {
      final start = (i * chunkSize).floor();
      final end = ((i + 1) * chunkSize).floor().clamp(
        start + 1,
        samples.length,
      );
      final chunk = samples.sublist(start, end);
      final avg = chunk.reduce((a, b) => a + b) / chunk.length;
      result.add(avg);
    }
    return result;
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    final dark = Theme.of(context).brightness == Brightness.dark;
    final barFill = dark ? context.brand.inputFill : Colors.white;
    final fg = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: barFill,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: dark
            ? Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live waveform during recording — uses ValueListenableBuilder
            // so only the bars repaint on amplitude changes, not the whole widget
            if (_isRecording && !_isSending)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: _amplitudeNotifier,
                  builder: (context, amplitudes, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildLiveWaveformBars(amplitudes),
                    );
                  },
                ),
              ),
            Row(
              children: [
                // Cancel button
                IconButton(
                  onPressed: _cancel,
                  icon: Icon(Icons.close, color: context.brand.errorRed),
                ),
                const SizedBox(width: 8),
                // Recording indicator (pulsing)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? context.brand.errorRed.withValues(
                                alpha: 0.5 + _pulseController.value * 0.5,
                              )
                            : context.brand.neutralGrey,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Timer
                Text(
                  '$minutes:$seconds',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: fg,
                  ),
                ),
                const Spacer(),
                // Animated recording text
                if (_isRecording && !_isSending)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) => Opacity(
                      opacity: 0.5 + _pulseController.value * 0.5,
                      child: Text(
                        'Εγγραφή...',
                        style: TextStyle(
                          color: context.brand.errorRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: _isSending
                        ? context.brand.neutralGrey
                        : context.brand.royalLavender,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _stopAndSend,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLiveWaveformBars(List<double> currentAmplitudes) {
    // Show last 30 amplitude samples
    const barCount = _waveformBarCount;
    final samples = currentAmplitudes.length > barCount
        ? currentAmplitudes.sublist(currentAmplitudes.length - barCount)
        : [
            ...currentAmplitudes,
            ...List.filled(barCount - currentAmplitudes.length, 0.0),
          ];

    return List.generate(barCount, (i) {
      final amplitude = i < samples.length ? samples[i] : 0.0;
      final barHeight = 4.0 + amplitude * 32.0;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: context.brand.royalLavender.withValues(
              alpha: 0.3 + amplitude * 0.7,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    });
  }
}

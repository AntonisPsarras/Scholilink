import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Future<void> compressPng(
  String path, {
  required int maxBytes,
  required List<int> tryWidths,
}) async {
  final file = File(path);
  final decoded = img.decodeImage(await file.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Failed to decode $path');
    exit(1);
  }

  Uint8List? best;
  var bestLabel = '';

  for (final width in tryWidths) {
    final resized = width >= decoded.width
        ? decoded
        : img.copyResize(decoded, width: width);
    final candidates = <(String, Uint8List)>[
      ('png', Uint8List.fromList(img.encodePng(resized, level: 9))),
      (
        'png-q256',
        Uint8List.fromList(
          img.encodePng(img.quantize(resized, numberOfColors: 256), level: 9),
        ),
      ),
      (
        'png-q128',
        Uint8List.fromList(
          img.encodePng(img.quantize(resized, numberOfColors: 128), level: 9),
        ),
      ),
    ];
    for (final (label, bytes) in candidates) {
      if (best == null || bytes.length < best.length) {
        best = bytes;
        bestLabel = '${width}px $label';
      }
      if (bytes.length <= maxBytes) {
        await file.writeAsBytes(bytes, flush: true);
        stdout.writeln(
          '$path -> ${bytes.length} bytes ($width px, $label)',
        );
        return;
      }
    }
  }

  if (best != null) {
    await file.writeAsBytes(best, flush: true);
    stdout.writeln(
      '$path -> ${best.length} bytes (best effort: $bestLabel, target $maxBytes)',
    );
  }
}

Future<void> main() async {
  await compressPng(
    'assets/branding/splash_logo.png',
    maxBytes: 200 * 1024,
    tryWidths: [1920, 1280, 1024, 800, 640, 512, 384],
  );
  await compressPng(
    'assets/branding/app_icon.png',
    maxBytes: 300 * 1024,
    tryWidths: [1024, 512, 384, 256],
  );
}

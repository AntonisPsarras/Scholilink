import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/file_saver.dart';
import '../../../shared/image_utils.dart'; // import for isBase64DataUri and decodeBase64DataUri

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  Future<void> _downloadImage(BuildContext context) async {
    if (isBase64DataUri(imageUrl)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot download local images yet')),
        );
      }
      return;
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Downloading image...')));
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final fileName =
            'scholilink_${DateTime.now().millisecondsSinceEpoch}.png';

        await saveImageToGallery(bytes, fileName);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved successfully!')),
          );
        }
      } else {
        throw Exception('Failed to fetch image data');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () => _downloadImage(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: isBase64DataUri(imageUrl)
                ? Image.memory(
                    Uint8List.fromList(decodeBase64DataUri(imageUrl)),
                    fit: BoxFit.contain,
                  )
                : Builder(
                    builder: (context) {
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final sz = MediaQuery.sizeOf(context);
                      final pxW = (sz.width * dpr).round();
                      final pxH = (sz.height * dpr).round();
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: pxW,
                        memCacheHeight: pxH,
                        maxWidthDiskCache: pxW,
                        maxHeightDiskCache: pxH,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

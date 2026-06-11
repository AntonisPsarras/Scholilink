import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../image_utils.dart';
import '../utils/file_saver.dart';

class FullScreenImageViewer extends ConsumerWidget {
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
        final bytes = response.bodyBytes;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sz = MediaQuery.sizeOf(context);
    final pxW = (sz.width * dpr).round();
    final pxH = (sz.height * dpr).round();

    final Widget imageBody;
    if (isBase64DataUri(imageUrl)) {
      final bytesAsync = ref.watch(base64ChatImageBytesProvider(imageUrl));
      imageBody = bytesAsync.when(
        data: (bytes) => Image.memory(
          bytes,
          fit: BoxFit.contain,
          cacheWidth: pxW,
          cacheHeight: pxH,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      );
    } else {
      imageBody = CachedNetworkImage(
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
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      );
    }

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
            child: imageBody,
          ),
        ),
      ),
    );
  }
}

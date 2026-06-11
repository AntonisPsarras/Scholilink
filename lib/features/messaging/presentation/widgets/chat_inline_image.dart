import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/image_utils.dart';
import '../../../../theme/app_theme.dart';

/// Inline chat image that preserves aspect ratio within bubble width.
class ChatInlineImage extends ConsumerWidget {
  const ChatInlineImage({
    super.key,
    required this.url,
    required this.heroTag,
    required this.onTap,
    this.errorLabel = 'Error loading',
  });

  final String url;
  final String heroTag;
  final VoidCallback onTap;
  final String errorLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.55;
    const maxHeight = 280.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (maxWidth * dpr).round();

    final Widget image;
    if (isBase64DataUri(url)) {
      final bytesAsync = ref.watch(base64ChatImageBytesProvider(url));
      image = bytesAsync.when(
        data: (bytes) => Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          cacheWidth: memW,
        ),
        loading: () => SizedBox(
          width: maxWidth,
          height: 120,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.brand.royalLavender.withValues(alpha: 0.6),
            ),
          ),
        ),
        error: (_, __) => _ImageErrorPlaceholder(
          maxWidth: maxWidth,
          label: errorLabel,
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        memCacheWidth: memW,
        maxWidthDiskCache: memW,
        placeholder: (_, __) => SizedBox(
          width: maxWidth,
          height: 120,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.brand.royalLavender.withValues(alpha: 0.6),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _ImageErrorPlaceholder(
          maxWidth: maxWidth,
          label: errorLabel,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: image,
          ),
        ),
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder({
    required this.maxWidth,
    required this.label,
  });

  final double maxWidth;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: maxWidth,
      height: 120,
      decoration: BoxDecoration(
        color: context.brand.neutralGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: context.brand.neutralGrey,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.brand.neutralGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

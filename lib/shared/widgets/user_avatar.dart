import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/avatar_assets.dart';
import '../../theme/app_theme.dart';
import '../image_utils.dart';

/// Decodes a data-URI avatar off the UI isolate when possible; cached per URI while watched.
final base64AvatarBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, dataUri) async {
      if (kIsWeb) {
        await Future<void>.delayed(Duration.zero);
        return Uint8List.fromList(decodeBase64DataUri(dataUri));
      }
      return compute(decodeBase64DataUriForIsolate, dataUri);
    });

class UserAvatar extends ConsumerWidget {
  final String? profilePictureUrl;
  final String fullName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.profilePictureUrl,
    required this.fullName,
    this.radius = 20.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profilePictureUrl != null && profilePictureUrl!.isNotEmpty) {
      if (_isLocalSvgAsset(profilePictureUrl!)) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
          child: ClipOval(
            child: SvgPicture.asset(
              profilePictureUrl!,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      if (isBase64DataUri(profilePictureUrl!)) {
        final bytesAsync = ref.watch(
          base64AvatarBytesProvider(profilePictureUrl!),
        );
        return bytesAsync.when(
          data: (bytes) => CircleAvatar(
            radius: radius,
            backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
            backgroundImage: MemoryImage(bytes),
          ),
          loading: () => CircleAvatar(
            radius: radius,
            backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
            child: ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: Center(
                  child: SizedBox(
                    width: (radius * 1.0).clamp(14.0, 22.0),
                    height: (radius * 1.0).clamp(14.0, 22.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.brand.royalLavender,
                    ),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => CircleAvatar(
            radius: radius,
            backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
            child: ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: _FallbackInner(
                  fullName: fullName,
                  radius: radius,
                  forceInitial: false,
                ),
              ),
            ),
          ),
        );
      }

      final dpr = MediaQuery.devicePixelRatioOf(context);
      final px = (radius * 2 * dpr).round();

      return CircleAvatar(
        radius: radius,
        backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: profilePictureUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            memCacheWidth: px,
            memCacheHeight: px,
            maxWidthDiskCache: px,
            maxHeightDiskCache: px,
            placeholder: (_, __) => Container(
              width: radius * 2,
              height: radius * 2,
              color: context.brand.royalLavender.withValues(alpha: 0.2),
            ),
            errorWidget: (_, __, ___) => _FallbackInner(
              fullName: fullName,
              radius: radius,
              forceInitial: false,
            ),
          ),
        ),
      );
    }

    return _buildFallbackAvatar(context);
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final fallbackAsset = _pickFallbackAsset(fullName);

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.brand.royalLavender.withValues(alpha: 0.2),
      child: ClipOval(
        child: SvgPicture.asset(
          fallbackAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            width: radius * 2,
            height: radius * 2,
            color: context.brand.royalLavender.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }

  bool _isLocalSvgAsset(String path) =>
      path.startsWith('assets/') && path.endsWith('.svg');

  String _pickFallbackAsset(String name) {
    final normalized = name.trim().isEmpty ? 'Student' : name.trim();
    final index =
        normalized.codeUnits.fold<int>(0, (sum, c) => sum + c) %
        avatarAssetPaths.length;
    return avatarAssetPaths[index];
  }
}

class _FallbackInner extends StatelessWidget {
  final String fullName;
  final double radius;
  final bool forceInitial;

  const _FallbackInner({
    required this.fullName,
    required this.radius,
    required this.forceInitial,
  });

  @override
  Widget build(BuildContext context) {
    if (forceInitial) return const SizedBox();

    final initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: context.brand.royalLavender,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

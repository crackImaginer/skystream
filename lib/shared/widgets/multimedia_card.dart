import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/responsive_breakpoints.dart';
import 'cards_wrapper.dart';
import 'shimmer_placeholder.dart';
import 'thumbnail_error_placeholder.dart';

class MultimediaCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final VoidCallback onTap;
  final String heroTag;
  final bool isPortrait;

  const MultimediaCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    required this.heroTag,
    this.isPortrait = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final cardWidth = isDesktop
        ? (isPortrait ? 200.0 : 300.0)
        : (isPortrait ? 130.0 : 200.0);
    // Decode at ~1.5× displayed width to look crisp on hi-DPR screens without
    // wasting memory. The full-res w500/w780 source would otherwise be decoded
    // 1:1 into the GPU even when displayed at 130 px.
    final memCacheWidth = (cardWidth * 1.5).round();

    return RepaintBoundary(
      child: CardsWrapper(
        onTap: onTap,
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      memCacheWidth: memCacheWidth,
                      placeholder: (context, url) =>
                          ShimmerPlaceholder(borderRadius: 12),
                      errorWidget: (_, _, _) =>
                          ThumbnailErrorPlaceholder(label: title),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: isDesktop ? 22 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

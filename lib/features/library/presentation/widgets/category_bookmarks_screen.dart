import 'package:flutter/material.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../core/domain/entity/multimedia_item.dart';

class CategoryBookmarksScreen extends StatelessWidget {
  final String categoryTitle;
  final List<MultimediaItem> items;

  const CategoryBookmarksScreen({
    super.key,
    required this.categoryTitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = context.isTabletOrLarger;
    final double totalHeight = isLarge ? 180.0 : 150.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: totalHeight,
          childAspectRatio: 2 / 3.4,
          crossAxisSpacing: LayoutConstants.spacingMd,
          mainAxisSpacing: LayoutConstants.spacingMd,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MultimediaCard(
            key: ValueKey(item.url),
            imageUrl: AppImageFallbacks.poster(item.posterUrl, label: item.title) ?? '',
            title: item.title,
            heroTag: 'lib_bookmark_detail_${item.url}_$index',
            onTap: () => DetailsRoute(
              $extra: DetailsRouteExtra(item: item),
            ).push<void>(context),
          );
        },
      ),
    );
  }
}
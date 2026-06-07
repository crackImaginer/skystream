import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../library_provider.dart';

import '../library_state.dart';

class BookmarksTab extends ConsumerStatefulWidget {
  const BookmarksTab({super.key});

  @override
  ConsumerState<BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends ConsumerState<BookmarksTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libraryState = ref.watch(libraryProvider);

    // Prevent crashing if the state is loading, empty, or error
    if (libraryState is! LibrarySuccess) {
      return _buildEmpty(context);
    }

    // CHANGED: Replaced Column with ListView to allow vertical scrolling of the entire page
    return ListView(
      padding: const EdgeInsets.only(bottom: LayoutConstants.spacingLg),
      children: [
        // Section header for Movies
        const ListTile(
          title: Text('Movies'),
        ),
        // Section content for Movies
        _buildSectionContent(
          libraryState.items
            .where((item) => item.contentType == MultimediaContentType.movie)
            .toList(),
        ),
        
        // Section header for TV Shows
        const ListTile(
          title: Text('TV Shows'),
        ),
        // Section content for TV Shows
        _buildSectionContent(
          libraryState.items
            .where((item) => item.contentType == MultimediaContentType.series) 
            .toList(),
        ),
        
        // Section header for Others
        const ListTile(
          title: Text('Others'),
        ),
        // Section content for Others
        _buildSectionContent(
          libraryState.items
            .where((item) => item.contentType != MultimediaContentType.movie && 
                             item.contentType != MultimediaContentType.series)
            .toList(),
        ),
      ],
    );
  }

  Widget _buildSectionContent(List<MultimediaItem> items) {
    // If there are no items in this section, don't render an empty space
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLarge = context.isTabletOrLarger;
    
    // Calculate exact dimensions to match your previous grid's aspect ratio
    // Previous childAspectRatio was 2 / 3.4 (width / height)
    final double cardWidth = isLarge ? 180.0 : 150.0;
    final double cardHeight = cardWidth * (3.4 / 2); 

    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // CHANGED: Replaced GridView with a horizontal ListView.builder
    return SizedBox(
      height: cardHeight, // Horizontal lists require a bounded height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LayoutConstants.spacingMd),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          
          return Padding(
            padding: const EdgeInsets.only(right: LayoutConstants.spacingMd),
            child: SizedBox(
              width: cardWidth, // Constrain the width of each card
              child: MultimediaCard(
                key: ValueKey(item.url),
                imageUrl:
                    AppImageFallbacks.poster(item.posterUrl, label: item.title) ??
                    '',
                title: item.title,
                heroTag: 'lib_bookmark_${item.url}_$index',
                onTap: () => DetailsRoute(
                  $extra: DetailsRouteExtra(item: item),
                ).push<void>(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 64,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.libraryEmpty,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
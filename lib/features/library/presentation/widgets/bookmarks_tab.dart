import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/utils/layout_constants.dart';
import '../library_provider.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import 'category_bookmarks_screen.dart';

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

  String _getCategoryName(MultimediaContentType type) {
    return switch (type) {
      MultimediaContentType.movie => 'Movies',
      MultimediaContentType.series => 'TV Shows',
      MultimediaContentType.livestream => 'Livestreams',
      MultimediaContentType.anime => 'Anime',
      MultimediaContentType.other => 'Others',
    };
  }

  IconData _getCategoryIcon(MultimediaContentType type) {
    return switch (type) {
      MultimediaContentType.movie => Icons.movie_outlined,
      MultimediaContentType.series => Icons.tv_outlined,
      MultimediaContentType.livestream => Icons.live_tv_outlined,
      MultimediaContentType.anime => Icons.animation_outlined,
      MultimediaContentType.other => Icons.folder_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libraryState = ref.watch(libraryProvider);

    return switch (libraryState) {
      LibraryLoading() => const Center(child: CircularProgressIndicator()),
      LibraryError(message: final msg) => Center(child: Text(msg)),
      LibraryEmpty() => _buildEmpty(context),
      LibrarySuccess(items: final items) => _buildFoldersView(context, items),
    };
  }

  Widget _buildFoldersView(BuildContext context, List<MultimediaItem> items) {
    // 1. Initialize map enforcing the order
    final groupedItems = {
      MultimediaContentType.movie: <MultimediaItem>[],
      MultimediaContentType.series: <MultimediaItem>[],
      MultimediaContentType.livestream: <MultimediaItem>[],
      MultimediaContentType.anime: <MultimediaItem>[],
      MultimediaContentType.other: <MultimediaItem>[],
    };

    // 2. Group items
    for (final item in items) {
      groupedItems[item.contentType]?.add(item);
    }

    // 3. Sort alphabetically and remove empty folders
    groupedItems.removeWhere((key, list) {
      if (list.isEmpty) return true;
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return false; 
    });

    // 4. Render the Folders List
    final activeCategories = groupedItems.entries.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(LayoutConstants.spacingMd),
      itemCount: activeCategories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = activeCategories[index];
        final title = _getCategoryName(entry.key);
        final icon = _getCategoryIcon(entry.key);
        final categoryItems = entry.value;

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${categoryItems.length} items'),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () {
              // Navigate to the specific category grid
              // Note: If you use a strict router setup like go_router, 
              // you may want to define a specific Route class for this in app_router.dart.
              // This standard push works perfectly as a drop-in.
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => CategoryBookmarksScreen(
                    categoryTitle: title,
                    items: categoryItems,
                  ),
                ),
              );
            },
          ),
        );
      },
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

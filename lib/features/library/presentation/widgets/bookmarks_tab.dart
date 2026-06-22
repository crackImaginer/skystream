import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/utils/layout_constants.dart';
import '../library_provider.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import 'category_bookmarks_screen.dart';
import '../library_state.dart';

import '../../../tracking/presentation/tracking_auth_provider.dart';
import '../../../tracking/presentation/trakt_bookmarks_provider.dart';

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
    final trackingAuthState = ref.watch(trackingAuthProvider);
    final traktBookmarksState = ref.watch(traktBookmarksProvider);

    // Extract auth state safely
    final isTraktLoggedIn = trackingAuthState.maybeWhen(
      data: (data) => data['trakt'] ?? false,
      orElse: () => false,
    );

    // Extract fetched Trakt items safely
    final List<MultimediaItem> traktItems = traktBookmarksState.maybeWhen(
      data: (items) => items,
      orElse: () => [],
    );

    return switch (libraryState) {
      LibraryLoading() => const Center(child: CircularProgressIndicator()),
      LibraryError(message: final msg) => Center(child: Text(msg)),
      LibraryEmpty() => _buildCombinedFoldersView(
          context, [], isTraktLoggedIn, traktItems, isLibraryEmpty: true),
      LibrarySuccess(items: final items) => _buildCombinedFoldersView(
          context, items, isTraktLoggedIn, traktItems, isLibraryEmpty: false),
    };
  }

  Widget _buildCombinedFoldersView(
    BuildContext context, 
    List<MultimediaItem> localItems, 
    bool isTraktLoggedIn,
    List<MultimediaItem> traktItems,
    {required bool isLibraryEmpty}
  ) {
    final List<Widget> listItems = [];

    // 1. Add Trakt Folder (Always at the top)
    listItems.add(
      Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            isTraktLoggedIn ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined, 
            size: 28, 
            color: isTraktLoggedIn ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
          ),
          title: const Text(
            'Trakt',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            isTraktLoggedIn ? '${traktItems.length} synced items' : 'Trakt service is not connected'
          ),
          trailing: isTraktLoggedIn ? const Icon(Icons.chevron_right_rounded) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: isTraktLoggedIn 
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => CategoryBookmarksScreen(
                      categoryTitle: 'Trakt Sync',
                      items: traktItems,
                    ),
                  ),
                );
              }
            : null,
        ),
      )
    );

    // 2. Add Local Folders or Empty State
    if (isLibraryEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 64.0),
          child: _buildEmptyIndicator(context),
        )
      );
    } else {
      final groupedItems = {
        MultimediaContentType.movie: <MultimediaItem>[],
        MultimediaContentType.series: <MultimediaItem>[],
        MultimediaContentType.livestream: <MultimediaItem>[],
        MultimediaContentType.anime: <MultimediaItem>[],
        MultimediaContentType.other: <MultimediaItem>[],
      };

      for (final item in localItems) {
        groupedItems[item.contentType]?.add(item);
      }

      groupedItems.removeWhere((key, list) {
        if (list.isEmpty) return true;
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return false; 
      });

      for (final entry in groupedItems.entries) {
        final title = _getCategoryName(entry.key);
        final icon = _getCategoryIcon(entry.key);
        final categoryItems = entry.value;

        listItems.add(
          Card(
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
          )
        );
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.all(LayoutConstants.spacingMd),
      itemCount: listItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => listItems[index],
    );
  }

  Widget _buildEmptyIndicator(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }
}
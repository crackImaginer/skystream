import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/storage/library_repository.dart';

import '../../tracking/data/trakt_service.dart';
import '../../tracking/presentation/tracking_auth_provider.dart';

import './library_state.dart';

part 'library_provider.g.dart';

@Riverpod(keepAlive: true)
class Library extends _$Library {
  @override
  LibraryState build() {
    // 1. Instantly load the local database for a fast UI
    final state = refresh();
    
    // 2. Trigger a background sync with Trakt on app startup
    _performTwoWaySync();
    
    return state;
  }

  LibraryState refresh() {
    final repository = ref.read(libraryRepositoryProvider);
    final items = repository.getLibraryItems();
    if (items.isEmpty) {
      state = const LibraryEmpty();
    } else {
      state = LibrarySuccess(items);
    }
    return state;
  }

  Future<void> addItem(MultimediaItem item) async {
    // 1. Add locally and update UI instantly
    final repository = ref.read(libraryRepositoryProvider);
    await repository.addToLibrary(item);
    refresh();

    // 2. Push to Trakt if it is a supported content type
    if (item.contentType == MultimediaContentType.movie || 
        item.contentType == MultimediaContentType.series) {
      
      final authState = await ref.read(trackingAuthProvider.future);
      final isTraktLoggedIn = authState['trakt'] ?? false;

      if (isTraktLoggedIn) {
        final traktService = ref.read(traktServiceProvider);
        final success = await traktService.addToPlanToWatch(item);
        
        if (!success) {
          // Sync failed, but the item is already safely stored in the local repository
        }
      }
    }
  }

  Future<void> removeItem(String url) async {
    final repository = ref.read(libraryRepositoryProvider);
    await repository.removeFromLibrary(url);
    refresh();
    
    // Note: To make removal two-way, you will eventually need to add a 
    // `removeFromWatchlist` API method to your TraktService.
  }

  bool isBookmarked(String url) {
    final repository = ref.read(libraryRepositoryProvider);
    return repository.isInLibrary(url);
  }

  Future<void> clearAll() async {
    // repository.clearAll() if it exists
  }

  // --- NEW: Trakt Watchlist Sync Logic ---
  
  Future<void> _performTwoWaySync() async {
    try {
      final authState = await ref.read(trackingAuthProvider.future);
      final isTraktLoggedIn = authState['trakt'] ?? false;

      if (!isTraktLoggedIn) return;

      final traktService = ref.read(traktServiceProvider);
      final repository = ref.read(libraryRepositoryProvider);

      // Pull the remote watchlist from Trakt
      final remoteItems = await traktService.getWatchlist();

      bool hasChanges = false;

      // Merge remote items into the local library
      for (final remoteItem in remoteItems) {
        // Only add if it does not already exist in the local database
        if (!repository.isInLibrary(remoteItem.url)) {
          await repository.addToLibrary(remoteItem);
          hasChanges = true;
        }
      }

      // If new items were pulled from Trakt, refresh the UI
      if (hasChanges) {
        refresh();
      }
    } catch (e) {
      // Background sync failed (e.g., no internet)
    }
  }
  
  // Expose this method if you want to add a manual "Pull-to-Refresh" 
  // indicator in your BookmarksTab UI later.
  Future<void> forceManualSync() async {
    await _performTwoWaySync();
  }
}
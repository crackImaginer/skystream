import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/storage/library_repository.dart';

// Using correct relative imports to match your architecture
import '../../tracking/presentation/tracking_auth_provider.dart'; 
import '../../tracking/data/trakt_service.dart';

import './library_state.dart';

part 'library_provider.g.dart';

@Riverpod(keepAlive: true)
class Library extends _$Library {
  @override
  LibraryState build() {
    // 1. Instantly load the local database for a fast UI
    final state = refresh();
    
    // 2. CRITICAL FIX: Add a 2-second delay to background sync. 
    // This allows Riverpod to finish building the entire app graph (including Settings UI) 
    // before the network calls are made.
    Future.delayed(const Duration(seconds: 2), () {
      _performTwoWaySync();
    });
    
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
    final repository = ref.read(libraryRepositoryProvider);
    await repository.addToLibrary(item);
    refresh();

    if (item.contentType == MultimediaContentType.movie || 
        item.contentType == MultimediaContentType.series) {
      
      final authState = await ref.read(trackingAuthProvider.future);
      final isTraktLoggedIn = authState['trakt'] ?? false;

      if (isTraktLoggedIn) {
        final traktService = ref.read(traktServiceProvider);
        await traktService.addToPlanToWatch(item);
      }
    }
  }

  Future<void> removeItem(String url) async {
    final repository = ref.read(libraryRepositoryProvider);
    await repository.removeFromLibrary(url);
    refresh();
  }

  bool isBookmarked(String url) {
    final repository = ref.read(libraryRepositoryProvider);
    return repository.isInLibrary(url);
  }

  Future<void> clearAll() async {
    // repository.clearAll() if it exists
  }

  // --- Trakt Watchlist Sync Logic ---
  Future<void> _performTwoWaySync() async {
    try {
      final authState = await ref.read(trackingAuthProvider.future);
      final isTraktLoggedIn = authState['trakt'] ?? false;

      if (!isTraktLoggedIn) return;

      final traktService = ref.read(traktServiceProvider);
      final repository = ref.read(libraryRepositoryProvider);

      final remoteItems = await traktService.getWatchlist();
      bool hasChanges = false;

      for (final remoteItem in remoteItems) {
        if (!repository.isInLibrary(remoteItem.url)) {
          await repository.addToLibrary(remoteItem);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        refresh();
      }
    } catch (e) {
      // Sync failed silently (e.g. no internet)
    }
  }
  
  Future<void> forceManualSync() async {
    await _performTwoWaySync();
  }
}